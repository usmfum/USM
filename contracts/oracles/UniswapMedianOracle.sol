// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./Median.sol";

contract UniswapMedianOracle is Oracle {
    using SafeMath for uint;

    uint private constant NUM_SOURCE_ORACLES = 3;

    IUniswapV2Pair[NUM_SOURCE_ORACLES] public pairs;
    bool[NUM_SOURCE_ORACLES] public tokensInReverseOrder;
    uint[NUM_SOURCE_ORACLES] public scaleFactors;

    /**
     *  Example pairs to pass in:
     *  ETH/USDT: 0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852, false, 10 ** 30 (since ETH/USDT has -12 dec places, and we want 18)
     *  USDC/ETH: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc, true, 10 ** 6 (since USDC/ETH has 12 dec places, and we want 18)
     *  DAI/ETH: 0xa478c2975ab1ea89e8196811f51a7b7ade33eb11, true, 10 ** 18 (since DAI/ETH has 0 dec places, and we want 18)
     */
    constructor(address[NUM_SOURCE_ORACLES] memory pairs_,
                bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder_,
                uint[NUM_SOURCE_ORACLES] memory scaleFactors_) public
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            pairs[i] = IUniswapV2Pair(pairs_[i]);
        }
        tokensInReverseOrder = tokensInReverseOrder_;
        scaleFactors = scaleFactors_;
    }

    function latestPrice() public virtual override view returns (uint price) {
        // For maximum gas efficiency...
        price = Median.median([latestUniswapPairPrice(pairs[0], tokensInReverseOrder[0], scaleFactors[0]),
                               latestUniswapPairPrice(pairs[1], tokensInReverseOrder[1], scaleFactors[1]),
                               latestUniswapPairPrice(pairs[2], tokensInReverseOrder[2], scaleFactors[2])]);
    }

    function latestUniswapPairPrice(IUniswapV2Pair pair, bool tokensInReverseOrder_, uint scaleFactor)
        internal view returns (uint price)
    {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        (uint112 reserveA, uint112 reserveB) = tokensInReverseOrder_ ? (reserve1, reserve0) : (reserve0, reserve1);
        price = (uint(reserveB)).mul(scaleFactor).div(uint(reserveA));
    }
}
