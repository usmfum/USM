// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USMTemplate.sol";
import "./oracles/MedianOracle.sol";


contract USM is USMTemplate, MedianOracle {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair[NUM_UNISWAP_PAIRS] memory uniswapPairs,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens0Decimals,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens1Decimals,
        bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder
    ) public
        USMTemplate()
        MedianOracle(chainlinkAggregator, compoundView,
                     uniswapPairs, uniswapTokens0Decimals, uniswapTokens1Decimals, uniswapTokensInReverseOrder) {}
}
