// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./OurUniswap.sol";
import "./Median.sol";

contract UniswapMedianTWAPOracle is Oracle {
    using SafeMath for uint;

    uint private constant WAD = 10 ** 18;
    uint private constant WAD_OVER_100 = WAD / 100;
    uint private constant UINT32_MAX = 2 ** 32 - 1;      // This should really be type(uint32).max, but requires Solidity 0.6.8...
    uint private constant TWO_TO_THE_48 = 2 ** 48;       // See below for how we use this
    uint private constant MAX_PRICE_SECONDS_CHANGE_WE_CAN_STORE = TWO_TO_THE_48 * WAD_OVER_100; // See unpackPriceSeconds()

    uint private constant NUM_SOURCE_ORACLES = 3;

    // Minimum age of the stored CumulativePrices we calculate our TWAP vs, and minimum gap between stored CumulativePrices.  See
    // also the more detailed explanation in OurUniswapV2TWAPOracle.
    uint private constant MIN_TWAP_PERIOD = 2 minutes;

    // Each CumulativePrices struct crams three pairs timestamps and cumulative prices ("price-seconds") into one 256-bit word.
    struct CumulativePrices {
        uint32 timestamp1;
        // priceSeconds = the pair's cumulative number of "price-seconds".  Eg, if at time t0 priceSeconds = 10,000,000 (stored as
        // 10,000,000 * 100 = 1,000,000,000), and during the 30 seconds between t0 and t1 = t0 + 30, the price is $45.67, then at
        // time t1 priceSeconds = 10,000,000 + 30 * 45.67 = 10,001,370.1 (stored as 10,001,370.1 * 100 = 1,000,137,010).  This is
        // just how Uniswap v2 TWAP prices work, we're just converting to 100-scaled ("pennies") format.  See also the WAD-scaled
        // version in OurUniswapV2TWAPOracle.
        uint48 priceSeconds1;
        uint32 timestamp2;
        uint48 priceSeconds2;
        uint32 timestamp3;
        uint48 priceSeconds3;
    }

    OurUniswap.Pair[NUM_SOURCE_ORACLES] private pairs;

    /**
     * We store two CumulativePrices, A and B, without specifying which is more recent.  This is so that we only need to do one
     * SSTORE each time we save a new one: we can inspect them later to figure out which is newer - see orderedStoredPrices().
     */
    CumulativePrices private storedPricesA;
    CumulativePrices private storedPricesB;

    /* ____________________ Constructor ____________________ */

    /**
     * See OurUniswapV2SpotOracle for example pairs to pass in
     */
    constructor(IUniswapV2Pair[NUM_SOURCE_ORACLES] memory uniswapPairs,
                uint[NUM_SOURCE_ORACLES] memory tokens0Decimals,
                uint[NUM_SOURCE_ORACLES] memory tokens1Decimals,
                bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder) public
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            pairs[i] = OurUniswap.createPair(uniswapPairs[i], tokens0Decimals[i], tokens1Decimals[i], tokensInReverseOrder[i]);
        }
    }

    /* ____________________ Public stateful functions ____________________ */

    function cacheLatestPrice() public virtual override returns (uint price) {
        (CumulativePrices storage olderStoredPrices, CumulativePrices storage newerStoredPrices) = orderedStoredPrices();

        uint[NUM_SOURCE_ORACLES] memory prices;
        uint[NUM_SOURCE_ORACLES] memory timestamps;
        uint[NUM_SOURCE_ORACLES] memory priceSeconds;
        (price, prices, timestamps, priceSeconds) = latestPrices(newerStoredPrices);

        if (areNewAndStoredPricesFarEnoughApart(timestamps, newerStoredPrices)) {
            storeCumulativePrices(timestamps, priceSeconds, olderStoredPrices);
        }
    }

    /* ____________________ Public view functions ____________________ */

    function latestPrice() public virtual override view returns (uint price) {
        price = latestUniswapMedianTWAPPrice();
    }

    function latestUniswapMedianTWAPPrice() public view returns (uint price) {
        (, CumulativePrices storage newerStoredPrices) = orderedStoredPrices();
        (price, , , ) = latestPrices(newerStoredPrices);
    }

    function latestUniswapPair1TWAPPrice() public view returns (uint price) {
        (, CumulativePrices storage newerStoredPrices) = orderedStoredPrices();
        (, uint[NUM_SOURCE_ORACLES] memory prices, , ) = latestPrices(newerStoredPrices);
        price = prices[0];
    }

    function latestUniswapPair2TWAPPrice() public view returns (uint price) {
        (, CumulativePrices storage newerStoredPrices) = orderedStoredPrices();
        (, uint[NUM_SOURCE_ORACLES] memory prices, , ) = latestPrices(newerStoredPrices);
        price = prices[1];
    }

    function latestUniswapPair3TWAPPrice() public view returns (uint price) {
        (, CumulativePrices storage newerStoredPrices) = orderedStoredPrices();
        (, uint[NUM_SOURCE_ORACLES] memory prices, , ) = latestPrices(newerStoredPrices);
        price = prices[2];
    }

    /* ____________________ Internal stateful functions ____________________ */

    function storeCumulativePrices(uint[NUM_SOURCE_ORACLES] memory timestamps,
                                   uint[NUM_SOURCE_ORACLES] memory priceSeconds,
                                   CumulativePrices storage olderStoredPrices)
        internal
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            require(timestamps[i] <= UINT32_MAX, "timestamp overflow");
        }

        // We need to make the priceSeconds representation more compact than our usual WAD fixed-point decimal, in order to pack
        // our update into a single 256-bit-word SSTORE.  So we store in "pennies" (2-decimal-place precision, rather than
        // 18-decimal-place).  This still gives quite accurate ETH *prices*: to within around $0.0001.
        // We also do "% TWO_TO_THE_48", rather than die on larger priceSeconds values with an overflow - see unpackPriceSeconds()
        // below for how we avoid overflow (reasonably) safely.
        // (Note: this assignment is only persistent because olderStoredPrices has modifier "storage" - ie, store by reference!)
        olderStoredPrices.timestamp1 = uint32(timestamps[0]);
        olderStoredPrices.timestamp2 = uint32(timestamps[1]);
        olderStoredPrices.timestamp3 = uint32(timestamps[2]);
        olderStoredPrices.priceSeconds1 = uint48((priceSeconds[0] / WAD_OVER_100) % TWO_TO_THE_48);
        olderStoredPrices.priceSeconds2 = uint48((priceSeconds[1] / WAD_OVER_100) % TWO_TO_THE_48);
        olderStoredPrices.priceSeconds3 = uint48((priceSeconds[2] / WAD_OVER_100) % TWO_TO_THE_48);
    }

    /* ____________________ Internal view functions ____________________ */

    function latestPrices(CumulativePrices storage newerStoredPrices) internal view
        returns (uint medianPrice,
                 uint[NUM_SOURCE_ORACLES] memory prices,
                 uint[NUM_SOURCE_ORACLES] memory timestamps,
                 uint[NUM_SOURCE_ORACLES] memory priceSeconds)
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            (timestamps[i], priceSeconds[i]) = OurUniswap.cumulativePrice(pairs[i]);
        }

        CumulativePrices storage refPrices = storedPricesToCompareVs(timestamps, newerStoredPrices);
        (uint[NUM_SOURCE_ORACLES] memory storedTimestamps, uint[NUM_SOURCE_ORACLES] memory storedPriceSeconds) =
            unpackStoredPrices(refPrices, priceSeconds);

        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            prices[i] = OurUniswap.calculateTWAP(timestamps[i], priceSeconds[i], storedTimestamps[i], storedPriceSeconds[i]);
        }
        medianPrice = Median.median(prices[0], prices[1], prices[2]);
    }

    function storedPricesToCompareVs(uint[NUM_SOURCE_ORACLES] memory newTimestamps, CumulativePrices storage newerStoredPrices)
        internal view returns (CumulativePrices storage refPrices)
    {
        bool aAcceptable = areNewAndStoredPricesFarEnoughApart(newTimestamps, storedPricesA);
        bool bAcceptable = areNewAndStoredPricesFarEnoughApart(newTimestamps, storedPricesB);

        if (aAcceptable && bAcceptable) {
            refPrices = newerStoredPrices;      // Neither is *too* recent, so return the fresher of the two
        } else if (aAcceptable) {
            refPrices = storedPricesA;          // Only A is acceptable
        } else if (bAcceptable) {
            refPrices = storedPricesB;          // Only B is acceptable
        } else {
            revert("Both stored prices too recent");
        }
    }

    /**
     * @return olderStoredPrices The older of the two stored CumulativePrices.
     * @return newerStoredPrices The newer of the two.
     */
    function orderedStoredPrices() internal view
        returns (CumulativePrices storage olderStoredPrices, CumulativePrices storage newerStoredPrices)
    {
        // Because we only store a new CumulativePrices if its three timestamps are *all* > those of the other stored
        // CumulativePrices, we can check which is newer by just comparing the first timestamp in each:
        (olderStoredPrices, newerStoredPrices) = storedPricesB.timestamp1 > storedPricesA.timestamp1 ?
            (storedPricesA, storedPricesB) : (storedPricesB, storedPricesA);
    }

    /* ____________________ Internal pure functions ____________________ */

    /**
     * @notice New prices should only be stored if all three of the new timestamps are >= MIN_TWAP_PERIOD fresher than their
     * corresponding latest stored timestamps: that is, we never want to store two cumulative prices < MIN_TWAP_PERIOD apart.
     */
    function areNewAndStoredPricesFarEnoughApart(uint[NUM_SOURCE_ORACLES] memory newTimestamps,
                                                 CumulativePrices storage storedPrices) internal view
        returns (bool farEnough)
    {
        farEnough = ((newTimestamps[0] >= (uint(storedPrices.timestamp1)).add(MIN_TWAP_PERIOD)) &&
                     (newTimestamps[1] >= (uint(storedPrices.timestamp2)).add(MIN_TWAP_PERIOD)) &&
                     (newTimestamps[2] >= (uint(storedPrices.timestamp3)).add(MIN_TWAP_PERIOD)));
    }

    /**
     * @notice Unpacks the compact stored CumulativePrices format (uint32s and uint48s) into regular WAD-scaled uints.
     */
    function unpackStoredPrices(CumulativePrices storage storedPrices, uint[NUM_SOURCE_ORACLES] memory latestPriceSeconds)
        internal view
        returns (uint[NUM_SOURCE_ORACLES] memory storedTimestamps, uint[NUM_SOURCE_ORACLES] memory storedPriceSeconds)
    {
        storedTimestamps[0] = storedPrices.timestamp1;
        storedTimestamps[1] = storedPrices.timestamp2;
        storedTimestamps[2] = storedPrices.timestamp3;

        // Convert the 100-scaled uint48 stored priceSeconds (eg, 58132, representing $581.32) into our usual WAD fixed-point
        // format (eg, 581.32 * 10**18):
        storedPriceSeconds[0] = unpackPriceSeconds(storedPrices.priceSeconds1, latestPriceSeconds[0]);
        storedPriceSeconds[1] = unpackPriceSeconds(storedPrices.priceSeconds2, latestPriceSeconds[1]);
        storedPriceSeconds[2] = unpackPriceSeconds(storedPrices.priceSeconds3, latestPriceSeconds[2]);
    }

    /**
     * @notice Unpacks a 100-scaled uint48 stored priceSeconds value (eg, 88358132, representing $882,581.32) into our usual WAD
     * fixed-point format (eg, 882,581.32 * 10**18).  The easy part here is multiplying by (10**18 / 100), but we also make an
     * adjustment if needed to account for the fact that we only store priceSeconds mod 2**48.  Here's an intuitive example using
     * decimals:
     *
     * Suppose we were storing priceSeconds % (10**6), ie, only the last 6 digits of the cumulative price.  As long as the stored
     * priceSeconds is < 1,000,000, the stored price = the actual price.  But suppose we have a stored priceSeconds of 998,621,
     * and also see that the latest priceSeconds from Uniswap is 23,000,067.  Then we can infer that the stored 998,621 probably
     * represents 22,998,621, not 998,621.  This is the adjustment we make below.
     *
     * Of course, we're making an assumption here: that the actual difference between the stored priceSeconds and Uniswap's latest
     * priceSeconds will never exceed the max value we can store (999,999 in the intuitive example above, 2**48 - 1 in our actual
     * code below).  This is a reasonable assumption though: a one-month gap between updates, during which ETH was priced at
     * $1,000,000, would still add less than 2**48 to priceSeconds.
     *
     * Without this adjustment, we'd be assuming not just that the *difference* between successive updates will always be < 2**48,
     * but that the priceSeconds value *itself* will always be < 2**48.  This would be a significantly shakier assumption.
     */
    function unpackPriceSeconds(uint48 storedPriceSeconds, uint latestPriceSeconds) internal pure returns (uint priceSeconds) {
        // First, convert to WAD format:
        priceSeconds = storedPriceSeconds * WAD_OVER_100;

        // Now, if priceSeconds is still more than MAX_PRICE_SECONDS_CHANGE_WE_CAN_STORE lower than latestPriceSeconds, adjust it:
        if (latestPriceSeconds >= priceSeconds + MAX_PRICE_SECONDS_CHANGE_WE_CAN_STORE) {
            // Following the intuitive example above: how do we calculate 22,998,621 from 23,000,067?  As follows:
            // 23,000,067 - ((23,000,067 - 998,621) % 1,000,000) = 22,998,621.
            priceSeconds = latestPriceSeconds - ((latestPriceSeconds - priceSeconds) % MAX_PRICE_SECONDS_CHANGE_WE_CAN_STORE);
        }
    }
}
