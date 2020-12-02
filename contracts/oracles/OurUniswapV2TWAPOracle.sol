// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./OurUniswap.sol";

contract OurUniswapV2TWAPOracle is Oracle {
    using SafeMath for uint;

    uint public constant UINT32_MAX = 2 ** 32 - 1;      // This should really be type(uint32).max, but requires Solidity 0.6.8...
    uint public constant UINT224_MAX = 2 ** 224 - 1;    // Ditto, type(uint224).max

    /**
     * MIN_TWAP_PERIOD plays two roles:
     *
     * 1. Minimum age of the stored CumulativePrice we calculate our current TWAP vs.  Eg, if one of our stored prices is from 5
     * secs ago, and the other from 10 min ago, we should calculate TWAP vs the 10-min-old one, since a 5-second TWAP is too
     * short - relatively easy to manipulate.
     *
     * 2. Minimum time gap between stored CumulativePrices.  Eg, if we stored one 5 seconds ago, we don't need to store another
     * one now - and shouldn't, since then if someone else made a TWAP call a few seconds later, both stored prices would be too
     * recent to calculate a robust TWAP.
     *
     * These roles could in principle be separated, eg: "Require the stored price we calculate TWAP from to be >= 2 minutes old,
     * but leave >= 10 minutes before storing a new price."  But for simplicity we keep them the same.
     */
    uint public constant MIN_TWAP_PERIOD = 2 minutes;

    struct CumulativePrice {
        uint32 timestamp;
        uint224 priceSeconds;   // See OurUniswap.cumulativePrice() for an explanation of "priceSeconds"
    }

    OurUniswap.Pair private pair;

    CumulativePrice private storedPriceA;
    CumulativePrice private storedPriceB;

    /**
     * See OurUniswapV2SpotOracle for example pairs to pass in.
     */
    constructor(IUniswapV2Pair uniswapPair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder) public {
        pair = OurUniswap.createPair(uniswapPair, token0Decimals, token1Decimals, tokensInReverseOrder);
    }

    function cacheLatestPrice() public virtual override returns (uint price) {
        (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();

        uint timestamp;
        uint priceSeconds;
        (price, timestamp, priceSeconds) = _latestPrice(newerStoredPrice);

        storePriceIfLatestStoredPriceIsStale(timestamp, priceSeconds, olderStoredPrice, newerStoredPrice);
    }

    function latestPrice() public virtual override view returns (uint price) {
        price = latestUniswapTWAPPrice();
    }

    function latestUniswapTWAPPrice() public view returns (uint price) {
        CumulativePrice storage newerStoredPrice;
        (, newerStoredPrice) = orderedStoredPrices();
        (price, , ) = _latestPrice(newerStoredPrice);
    }

    function _latestPrice(CumulativePrice storage newerStoredPrice)
        internal view returns (uint price, uint timestamp, uint priceSeconds)
    {
        (timestamp, priceSeconds) = OurUniswap.cumulativePrice(pair);

        // Now that we have the current cum price, subtract-&-divide the stored one, to get the TWAP price:
        CumulativePrice storage refPrice = storedPriceToCompareVs(timestamp, newerStoredPrice);
        price = OurUniswap.calculateTWAP(timestamp, priceSeconds, uint(refPrice.timestamp), uint(refPrice.priceSeconds));
    }

    function storePriceIfLatestStoredPriceIsStale(
        uint timestamp, uint priceSeconds,
        CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice
    ) internal
    {
        // Store the latest price, if it's been long enough since the latest stored price:
        if (areNewAndStoredPriceFarEnoughApart(timestamp, newerStoredPrice)) {
            require(timestamp <= UINT32_MAX, "timestamp overflow");
            require(priceSeconds <= UINT224_MAX, "priceSeconds overflow");
            // This assignment is only persistent because older has modifier "storage" - ie, store by reference!
            (olderStoredPrice.timestamp, olderStoredPrice.priceSeconds) = (uint32(timestamp), uint224(priceSeconds));
        }
    }

    function storedPriceToCompareVs(uint newTimestamp, CumulativePrice storage newerStoredPrice)
        internal view returns (CumulativePrice storage refPrice)
    {
        bool aAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceA);
        bool bAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceB);
        if (aAcceptable && bAcceptable) {
            refPrice = newerStoredPrice;        // Neither is *too* recent, so return the fresher of the two
        } else if (aAcceptable) {
            refPrice = storedPriceA;            // Only A is acceptable
        } else if (bAcceptable) {
            refPrice = storedPriceB;            // Only B is acceptable
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
        farEnough = newTimestamp >= (uint(storedPrice.timestamp)).add(MIN_TWAP_PERIOD);
    }
}
