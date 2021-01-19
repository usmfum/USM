// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";

contract OurUniswapV2TWAPOracle is Oracle {
    using SafeMath for uint;

    /**
     * MIN_TWAP_PERIOD plays two roles:
     *
     * 1. Minimum age of the stored CumulativePrice we calculate our current TWAP vs.  Eg, if one of our stored prices is from
     * 5 secs ago, and the other from 10 min ago, we should calculate TWAP vs the 10-min-old one, since a 5-second TWAP is too
     * short - relatively easy to manipulate.
     *
     * 2. Minimum time gap between stored CumulativePrices.  Eg, if we stored one 5 seconds ago, we don't need to store another
     * one now - and shouldn't, since then if someone else made a TWAP call a few seconds later, both stored prices would be
     * too recent to calculate a robust TWAP.
     *
     * These roles could in principle be separated, eg: "Require the stored price we calculate TWAP from to be >= 2 minutes
     * old, but leave >= 10 minutes before storing a new price."  But for simplicity we manage both with one constant.
     */
    uint public constant MIN_TWAP_PERIOD = 10 minutes;

    // Uniswap stores its cumulative prices in "FixedPoint.uq112x112" format - 112-bit fixed point:
    uint public constant UNISWAP_CUM_PRICE_SCALE_FACTOR = 2 ** 112;

    uint private constant UINT32_MAX = 2 ** 32 - 1;     // Should really be type(uint32).max, but that needs Solidity 0.6.8...
    uint private constant UINT224_MAX = 2 ** 224 - 1;   // Ditto, type(uint224).max

    IUniswapV2Pair public immutable uniswapPair;
    uint public immutable token0Decimals;
    uint public immutable token1Decimals;
    bool public immutable tokensInReverseOrder;
    uint public immutable scaleFactor;

    struct CumulativePrice {
        uint32 timestamp;
        uint224 cumPriceSeconds;    // See cumulativePrice() below for an explanation of "cumPriceSeconds"
    }

    event TWAPPriceStored(uint32 timestamp, uint224 priceSeconds);

    /**
     * We store two CumulativePrices, A and B, without specifying which is more recent.  This is so that we only need to do one
     * SSTORE each time we save a new one: we can inspect them later to figure out which is newer - see orderedStoredPrices().
     */
    CumulativePrice public storedUniswapPriceA;
    CumulativePrice public storedUniswapPriceB;

    /**
     * Example pairs to pass in:
     * ETH/USDT: 0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852, false, 18, 6 (WETH reserve is stored w/ 18 dec places, USDT w/ 18)
     * USDC/ETH: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc, true, 6, 18 (USDC reserve is stored w/ 6 dec places, WETH w/ 18)
     * DAI/ETH: 0xa478c2975ab1ea89e8196811f51a7b7ade33eb11, true, 18, 18 (DAI reserve is stored w/ 18 dec places, WETH w/ 18)
     */
    constructor(IUniswapV2Pair uniswapPair_, uint token0Decimals_, uint token1Decimals_, bool tokensInReverseOrder_) public {
        uniswapPair = uniswapPair_;
        token0Decimals = token0Decimals_;
        token1Decimals = token1Decimals_;
        tokensInReverseOrder = tokensInReverseOrder_;

        (uint aDecimals, uint bDecimals) = tokensInReverseOrder_ ?
            (token1Decimals_, token0Decimals_) :
            (token0Decimals_, token1Decimals_);
        scaleFactor = 10 ** aDecimals.add(18).sub(bDecimals);
    }

    function refreshPrice() public virtual override returns (uint price, uint updateTime) {
        (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();

        uint newCumPriceSecondsTime;
        uint newCumPriceSeconds;
        // "updateTime" aka "refCumPriceSecondsTime" - timestamp of the stored cumPriceSeconds value we're calculating TWAP vs:
        (price, updateTime, newCumPriceSecondsTime, newCumPriceSeconds) = _latestPrice(newerStoredPrice);

        // Store the latest cumulative price, if it's been long enough since the latest stored price:
        if (areNewAndStoredPriceFarEnoughApart(newCumPriceSecondsTime, newerStoredPrice)) {
            storeCumulativePrice(newCumPriceSecondsTime, newCumPriceSeconds, olderStoredPrice);
        }
    }

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime) = latestUniswapTWAPPrice();
    }

    function latestUniswapTWAPPrice() public view returns (uint price, uint updateTime) {
        (, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();
        (price, updateTime,,) = _latestPrice(newerStoredPrice);
    }

    /**
     * @notice There's an important distinction here between the two timestamps used here:
     *
     * - `newCumPriceSecondsTime` = the timestamp of the *latest cumulative price-seconds* available from Uniswap.  This is a
     *   real-time value that will (typically) change every time this function is called.
     * - `updateTime` = the timestamp of refPrice, the *stored cumulative price-seconds record we calculate TWAP from.*  This
     *   is a value we only store periodically: if this function is called often, it will usually stay unchanged between calls.
     *
     * That is, calcuating TWAP requires two cumPriceSeconds values to average between, and these are their timestamps.
     *
     * The most important - potentially confusing - part of this distinction is this: even though the *price* returned will
     * (typically) change every time this function is called, the *`updateTime`* will only change every few minutes, when we
     * update the older of the two cumPriceSeconds in the TWAP.  The principle there is that "the TWAP is only as fresh as the
     * *older* of the two cumPriceSeconds that go into it": if we're calculating a TWAP between one record 5 seconds old and
     * another a day old, it's more accurate to think of that TWAP as "a day old" than "5 seconds fresh".
     */
    function _latestPrice(CumulativePrice storage newerStoredPrice)
        internal view returns (uint price, uint updateTime, uint newCumPriceSecondsTime, uint newCumPriceSeconds)
    {
        (newCumPriceSecondsTime, newCumPriceSeconds) = cumulativePrice();

        // Now that we have the current cum price, subtract-&-divide the stored one, to get the TWAP price:
        CumulativePrice storage refPrice = storedPriceToCompareVs(newCumPriceSecondsTime, newerStoredPrice);
        updateTime = uint(refPrice.timestamp);
        price = calculateTWAP(newCumPriceSecondsTime, newCumPriceSeconds, updateTime, uint(refPrice.cumPriceSeconds));
    }

    function storeCumulativePrice(uint timestamp, uint cumPriceSeconds, CumulativePrice storage olderStoredPrice) internal
    {
        require(timestamp <= UINT32_MAX, "timestamp overflow");
        require(cumPriceSeconds <= UINT224_MAX, "cumPriceSeconds overflow");
        // (Note: this assignment only stores because olderStoredPrice has modifier "storage" - ie, store by reference!)
        (olderStoredPrice.timestamp, olderStoredPrice.cumPriceSeconds) = (uint32(timestamp), uint224(cumPriceSeconds));

        emit TWAPPriceStored(uint32(timestamp), uint224(cumPriceSeconds)); // 4k gas, is it worth it?
    }

    function storedPriceToCompareVs(uint newCumPriceSecondsTime, CumulativePrice storage newerStoredPrice)
        internal view returns (CumulativePrice storage refPrice)
    {
        bool aAcceptable = areNewAndStoredPriceFarEnoughApart(newCumPriceSecondsTime, storedUniswapPriceA);
        bool bAcceptable = areNewAndStoredPriceFarEnoughApart(newCumPriceSecondsTime, storedUniswapPriceB);
        if (aAcceptable) {
            if (bAcceptable) {
                refPrice = newerStoredPrice;        // Neither is *too* recent, so return the fresher of the two
            } else {
                refPrice = storedUniswapPriceA;     // Only A is acceptable
            }
        } else if (bAcceptable) {
            refPrice = storedUniswapPriceB;         // Only B is acceptable
        } else {
            revert("Both stored prices too recent");
        }
    }

    function orderedStoredPrices() internal view
        returns (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice)
    {
        (olderStoredPrice, newerStoredPrice) = storedUniswapPriceB.timestamp > storedUniswapPriceA.timestamp ?
            (storedUniswapPriceA, storedUniswapPriceB) : (storedUniswapPriceB, storedUniswapPriceA);
    }

    function areNewAndStoredPriceFarEnoughApart(uint newTimestamp, CumulativePrice storage storedPrice) internal view
        returns (bool farEnough)
    {
        farEnough = newTimestamp >= storedPrice.timestamp + MIN_TWAP_PERIOD;    // No risk of overflow on a uint32
    }

    /**
     * @return timestamp Timestamp at which Uniswap stored the cumPriceSeconds.
     * @return cumPriceSeconds Our pair's cumulative "price-seconds", using Uniswap's TWAP logic.  Eg, if at time t0
     * cumPriceSeconds = 10,000,000 (returned here as 10,000,000 * 10**18, ie, in WAD fixed-point format), and during the 30
     * seconds between t0 and t1 = t0 + 30, the price is $45.67, then at time t1, cumPriceSeconds = 10,000,000 + 30 * 45.67 =
     * 10,001,370.1 (stored as 10,001,370.1 * 10**18).
     */
    function cumulativePrice()
        public view returns (uint timestamp, uint cumPriceSeconds)
    {
        (, , timestamp) = uniswapPair.getReserves();

        // Retrieve the current Uniswap cumulative price.  Modeled off of Uniswap's own example:
        // https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
        uint uniswapCumPrice = tokensInReverseOrder ?
            uniswapPair.price1CumulativeLast() :
            uniswapPair.price0CumulativeLast();
        cumPriceSeconds = uniswapCumPrice.mul(scaleFactor) / UNISWAP_CUM_PRICE_SCALE_FACTOR;
    }

    /**
     * @param newTimestamp in seconds (eg, 1606764888) - not WAD-scaled!
     * @param newCumPriceSeconds WAD-scaled.
     * @param oldTimestamp in raw seconds again.
     * @param oldCumPriceSeconds WAD-scaled.
     * @return price WAD-scaled.
     */
    function calculateTWAP(uint newTimestamp, uint newCumPriceSeconds, uint oldTimestamp, uint oldCumPriceSeconds)
        public pure returns (uint price)
    {
        price = (newCumPriceSeconds.sub(oldCumPriceSeconds)).div(newTimestamp.sub(oldTimestamp));
    }
}
