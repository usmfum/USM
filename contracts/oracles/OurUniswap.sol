// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

library OurUniswap {
    using SafeMath for uint;

    // Uniswap stores its cumulative prices in "FixedPoint.uq112x112" format - 112-bit fixed point:
    uint public constant UNISWAP_CUM_PRICE_SCALE_FACTOR = 2 ** 112;

    struct Pair {
        IUniswapV2Pair uniswapPair;
        uint token0Decimals;
        uint token1Decimals;
        bool tokensInReverseOrder;
        uint scaleFactor;
    }

    function createPair(IUniswapV2Pair uniswapPair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder)
        internal pure returns (Pair memory pair)
    {
        pair.uniswapPair = uniswapPair;
        pair.token0Decimals = token0Decimals;
        pair.token1Decimals = token1Decimals;
        pair.tokensInReverseOrder = tokensInReverseOrder;

        (uint aDecimals, uint bDecimals) = tokensInReverseOrder ?
            (token1Decimals, token0Decimals) :
            (token0Decimals, token1Decimals);
        pair.scaleFactor = 10 ** aDecimals.add(18).sub(bDecimals);
    }

    /**
     * @return price WAD-formatted - 18 decimal places fixed-point.
     */
    function spotPrice(Pair storage pair)
        internal view returns (uint price)
    {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint112 reserve0, uint112 reserve1, ) = pair.uniswapPair.getReserves();
        (uint reserveA, uint reserveB) = pair.tokensInReverseOrder ?
            (uint(reserve1), uint(reserve0)) :
            (uint(reserve0), uint(reserve1));
        price = reserveB.mul(pair.scaleFactor).div(reserveA);
    }

    /**
     * @return timestamp Timestamp at which Uniswap stored the priceSeconds.
     * @return priceSeconds The pair's cumulative "price-seconds", using Uniswap's TWAP logic.  Eg, if at time t0
     * priceSeconds = 10,000,000 (returned here as 10,000,000 * 10**18, ie, in WAD fixed-point format), and during the 30
     * seconds between t0 and t1 = t0 + 30, the price is $45.67, then at time t1, priceSeconds = 10,000,000 + 30 * 45.67 =
     * 10,001,370.1 (stored as 10,001,370.1 * 10**18).
     */
    function cumulativePrice(Pair storage pair)
        internal view returns (uint timestamp, uint priceSeconds)
    {
        (, , timestamp) = pair.uniswapPair.getReserves();

        // Retrieve the current Uniswap cumulative price.  Modeled off of Uniswap's own example:
        // https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
        uint uniswapCumPrice = pair.tokensInReverseOrder ?
            pair.uniswapPair.price1CumulativeLast() :
            pair.uniswapPair.price0CumulativeLast();
        priceSeconds = uniswapCumPrice.mul(pair.scaleFactor) / UNISWAP_CUM_PRICE_SCALE_FACTOR;
    }

    /**
     * @param newTimestamp in seconds (eg, 1606764888) - not WAD-scaled!
     * @param newPriceSeconds WAD-scaled.
     * @param oldTimestamp in raw seconds again.
     * @param oldPriceSeconds WAD-scaled.
     * @return price WAD-scaled.
     */
    function calculateTWAP(uint newTimestamp, uint newPriceSeconds, uint oldTimestamp, uint oldPriceSeconds)
        internal pure returns (uint price)
    {
        price = (newPriceSeconds.sub(oldPriceSeconds)).div(newTimestamp.sub(oldTimestamp));
    }
}
