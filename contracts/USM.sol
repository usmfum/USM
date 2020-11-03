// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USMTemplate.sol";
import "./oracles/MedianOracle.sol";
// import "@nomiclabs/buidler/console.sol";

contract USM is USMTemplate, MedianOracle {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(address eth, address chainlinkAggregator, address compoundView,
                address[NUM_UNISWAP_PAIRS] memory uniswapPairs, bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder,
                uint[NUM_UNISWAP_PAIRS] memory uniswapScaleFactors) public
        USMTemplate(eth)
        MedianOracle(chainlinkAggregator, compoundView, uniswapPairs, uniswapTokensInReverseOrder, uniswapScaleFactors) {}
}
