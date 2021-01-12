// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USMTemplate.sol";
import "./oracles/MedianOracle.sol";

contract USM is USMTemplate, MedianOracle {
    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        USMTemplate()
        MedianOracle(chainlinkAggregator, compoundView,
                     uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function cacheLatestPrice() public virtual override(Oracle, MedianOracle) returns (uint price, uint updateTime) {
        (price, updateTime) = super.cacheLatestPrice();
    }
}
