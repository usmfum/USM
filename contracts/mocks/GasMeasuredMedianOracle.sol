// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/MedianOracle.sol";

contract GasMeasuredMedianOracle is MedianOracle, GasMeasuredOracle("median") {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(address chainlinkAggregator, address compoundView,
                address[NUM_UNISWAP_PAIRS] memory uniswapPairs, bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder,
                uint[NUM_UNISWAP_PAIRS] memory uniswapScaleFactors) public
        MedianOracle(chainlinkAggregator, compoundView, uniswapPairs, uniswapTokensInReverseOrder, uniswapScaleFactors) {}
}
