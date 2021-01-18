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
     * old, but leave >= 10 minutes before storing a new price."  But for simplicity we keep them the same.
     */
    uint public constant MIN_TWAP_PERIOD = 2 minutes;

    // Uniswap stores its cumulative prices in "FixedPoint.uq112x112" format - 112-bit fixed point:
    uint public constant UNISWAP_CUM_PRICE_SCALE_FACTOR = 2 ** 112;

    uint private constant UINT32_MAX = 2 ** 32 - 1;     // Should really be type(uint32).max, but that needs Solidity 0.6.8...
    uint private constant UINT224_MAX = 2 ** 224 - 1;   // Ditto, type(uint224).max

    IUniswapV2Pair immutable uniswapPair;
    uint immutable token0Decimals;
    uint immutable token1Decimals;
    bool immutable tokensInReverseOrder;
    uint immutable scaleFactor;

    struct CumulativePrice {
        uint32 timestamp;
        uint224 priceSeconds;   // See cumulativePrice() below for an explanation of "priceSeconds"
    }

    /**
     * We store two CumulativePrices, A and B, without specifying which is more recent.  This is so that we only need to do one
     * SSTORE each time we save a new one: we can inspect them later to figure out which is newer - see orderedStoredPrices().
     */
    CumulativePrice public storedPriceA;
    CumulativePrice public storedPriceB;

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

    function cacheLatestPrice() public virtual override returns (uint price) {
        (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();

        uint timestamp;
        uint priceSeconds;
        (price, timestamp, priceSeconds) = _latestPrice(newerStoredPrice);

        // Store the latest cumulative price, if it's been long enough since the latest stored price:
        if (areNewAndStoredPriceFarEnoughApart(timestamp, newerStoredPrice)) {
            storeCumulativePrice(timestamp, priceSeconds, olderStoredPrice);
        }
    }

    function latestPrice() public virtual override view returns (uint price) {
        price = latestUniswapTWAPPrice();
    }

    function latestUniswapTWAPPrice() public view returns (uint price) {
        (, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();
        (price, , ) = _latestPrice(newerStoredPrice);
    }

    function _latestPrice(CumulativePrice storage newerStoredPrice)
        internal view returns (uint price, uint timestamp, uint priceSeconds)
    {
        (timestamp, priceSeconds) = cumulativePrice();

        // Now that we have the current cum price, subtract-&-divide the stored one, to get the TWAP price:
        CumulativePrice storage refPrice = storedPriceToCompareVs(timestamp, newerStoredPrice);
        price = calculateTWAP(timestamp, priceSeconds, uint(refPrice.timestamp), uint(refPrice.priceSeconds));
    }

    function storeCumulativePrice(uint timestamp, uint priceSeconds, CumulativePrice storage olderStoredPrice) internal
    {
        require(timestamp <= UINT32_MAX, "timestamp overflow");
        require(priceSeconds <= UINT224_MAX, "priceSeconds overflow");
        // (Note: this assignment only stores because olderStoredPrice has modifier "storage" - ie, store by reference!)
        (olderStoredPrice.timestamp, olderStoredPrice.priceSeconds) = (uint32(timestamp), uint224(priceSeconds));
    }

    function storedPriceToCompareVs(uint newTimestamp, CumulativePrice storage newerStoredPrice)
        internal view returns (CumulativePrice storage refPrice)
    {
        bool aAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceA);
        bool bAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceB);
        if (aAcceptable) {
            if (bAcceptable) {
                refPrice = newerStoredPrice;        // Neither is *too* recent, so return the fresher of the two
            } else {
                refPrice = storedPriceA;            // Only A is acceptable
            }
        } else if (bAcceptable) {
            refPrice = storedPriceB;                // Only B is acceptable
        } else {
            revert("Both stored prices too recent");
        }
    }

    function orderedStoredPrices() internal view
        returns (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice)
    {
        (olderStoredPrice, newerStoredPrice) = storedPriceB.timestamp > storedPriceA.timestamp ?
            (storedPriceA, storedPriceB) : (storedPriceB, storedPriceA);
    }

    function areNewAndStoredPriceFarEnoughApart(uint newTimestamp, CumulativePrice storage storedPrice) internal view
        returns (bool farEnough)
    {
        farEnough = newTimestamp >= storedPrice.timestamp + MIN_TWAP_PERIOD;    // No risk of overflow on a uint32
    }

    /**
     * @return timestamp Timestamp at which Uniswap stored the priceSeconds.
     * @return priceSeconds Our pair's cumulative "price-seconds", using Uniswap's TWAP logic.  Eg, if at time t0
     * priceSeconds = 10,000,000 (returned here as 10,000,000 * 10**18, ie, in WAD fixed-point format), and during the 30
     * seconds between t0 and t1 = t0 + 30, the price is $45.67, then at time t1, priceSeconds = 10,000,000 + 30 * 45.67 =
     * 10,001,370.1 (stored as 10,001,370.1 * 10**18).
     */
    function cumulativePrice()
        public view returns (uint timestamp, uint priceSeconds)
    {
        (, , timestamp) = uniswapPair.getReserves();

        // Retrieve the current Uniswap cumulative price.  Modeled off of Uniswap's own example:
        // https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
        uint uniswapCumPrice = tokensInReverseOrder ?
            uniswapPair.price1CumulativeLast() :
            uniswapPair.price0CumulativeLast();
        priceSeconds = uniswapCumPrice.mul(scaleFactor) / UNISWAP_CUM_PRICE_SCALE_FACTOR;
    }

    /**
     * @param newTimestamp in seconds (eg, 1606764888) - not WAD-scaled!
     * @param newPriceSeconds WAD-scaled.
     * @param oldTimestamp in raw seconds again.
     * @param oldPriceSeconds WAD-scaled.
     * @return price WAD-scaled.
     */
    function calculateTWAP(uint newTimestamp, uint newPriceSeconds, uint oldTimestamp, uint oldPriceSeconds)
        public pure returns (uint price)
    {
        price = (newPriceSeconds.sub(oldPriceSeconds)).div(newTimestamp.sub(oldTimestamp));
    }
}
