// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USMTemplate.sol";
import "./oracles/MedianOracle.sol";


contract USM is USMTemplate, MedianOracle {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        IWETH9 eth,
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair[NUM_UNISWAP_PAIRS] memory uniswapPairs,
        bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder,
        uint[NUM_UNISWAP_PAIRS] memory uniswapScaleFactors
    ) public
        USMTemplate(eth)
        MedianOracle(chainlinkAggregator, compoundView, uniswapPairs, uniswapTokensInReverseOrder, uniswapScaleFactors) {}
}
