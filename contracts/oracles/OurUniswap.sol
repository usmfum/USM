// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

library OurUniswap {
    using SafeMath for uint;

    struct Pair {
        IUniswapV2Pair uniswapPair;
        uint token0Decimals;
        uint token1Decimals;
        bool tokensInReverseOrder;
        uint scaleFactor;
    }

    function createPair(IUniswapV2Pair uniswapPair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder)
        internal returns (Pair memory pair)
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
}
