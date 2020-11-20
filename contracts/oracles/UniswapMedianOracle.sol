// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./Median.sol";

contract UniswapMedianOracle is Oracle {
    using SafeMath for uint;

    uint private constant NUM_SOURCE_ORACLES = 3;

    struct UniswapPriceablePair {
        IUniswapV2Pair pair;
        bool tokensInReverseOrder;
        uint scaleFactor;
    }

    UniswapPriceablePair[NUM_SOURCE_ORACLES] private pairs;

    /**
     *  See OurUniswapV2SpotOracle for example pairs to pass in
     */
    constructor(IUniswapV2Pair[NUM_SOURCE_ORACLES] memory pairs_,
                bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder,
                uint[NUM_SOURCE_ORACLES] memory scaleFactors) public
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            pairs[i] = UniswapPriceablePair(pairs_[i], tokensInReverseOrder[i], scaleFactors[i]);
        }
    }

    function latestPrice() public virtual override view returns (uint price) {
        price = latestUniswapMedianPrice();
    }

    function latestUniswapMedianPrice() public view returns (uint price) {
        // For maximum gas efficiency...
        price = Median.median(latestUniswapPairPrice(pairs[0]),
                              latestUniswapPairPrice(pairs[1]),
                              latestUniswapPairPrice(pairs[2]));
    }

    function latestUniswapPair1Price() public view returns (uint price) {
        price = latestUniswapPairPrice(pairs[0]);
    }

    function latestUniswapPair2Price() public view returns (uint price) {
        price = latestUniswapPairPrice(pairs[1]);
    }

    function latestUniswapPair3Price() public view returns (uint price) {
        price = latestUniswapPairPrice(pairs[2]);
    }

    /**
     *  Cribbed from OurUniswapV2SpotOracle.latestPrice()...  Unfortunately our "inheritance in place of composition" design
     *  doesn't let us easily share that code
     */
    function latestUniswapPairPrice(UniswapPriceablePair memory pair)
        internal view returns (uint price)
    {
        (uint112 reserve0, uint112 reserve1,) = pair.pair.getReserves();
        (uint112 reserveA, uint112 reserveB) = pair.tokensInReverseOrder ? (reserve1, reserve0) : (reserve0, reserve1);
        price = (uint(reserveB)).mul(pair.scaleFactor).div(uint(reserveA));
    }
}
