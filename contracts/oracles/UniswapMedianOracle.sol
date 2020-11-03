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
     *  See OurUniswapV2SpotOracle for example pairs to pass in
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

    /**
     *  Cribbed from OurUniswapV2SpotOracle.latestPrice()...  Unfortunately our "inheritance in place of composition" design
     *  doesn't let us easily share that code
     */
    function latestUniswapPairPrice(IUniswapV2Pair pair, bool tokensInReverseOrder_, uint scaleFactor)
        internal view returns (uint price)
    {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        (uint112 reserveA, uint112 reserveB) = tokensInReverseOrder_ ? (reserve1, reserve0) : (reserve0, reserve1);
        price = (uint(reserveB)).mul(scaleFactor).div(uint(reserveA));
    }
}
