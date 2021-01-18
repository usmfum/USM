// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./OurUniswapV2TWAPOracle.sol";

contract MedianOracle is ChainlinkOracle, CompoundOpenOracle, OurUniswapV2TWAPOracle {
    using SafeMath for uint;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        OurUniswapV2TWAPOracle(uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function latestPrice() public override(ChainlinkOracle, CompoundOpenOracle, OurUniswapV2TWAPOracle)
        view returns (uint price)
    {
        price = median(ChainlinkOracle.latestPrice(),
                       CompoundOpenOracle.latestPrice(),
                       OurUniswapV2TWAPOracle.latestPrice());
    }

    function cacheLatestPrice() public virtual override(Oracle, OurUniswapV2TWAPOracle) returns (uint price) {
        price = median(ChainlinkOracle.latestPrice(),              // Not ideal to call latestPrice() on two of these
                       CompoundOpenOracle.latestPrice(),           // and cacheLatestPrice() on one...  But works, and
                       OurUniswapV2TWAPOracle.cacheLatestPrice()); // inheriting them like this saves significant gas
    }

    /**
     * @notice Currently only supports three inputs
     * @return median value
     */
    function median(uint a, uint b, uint c)
        public pure returns (uint)
    {
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}
