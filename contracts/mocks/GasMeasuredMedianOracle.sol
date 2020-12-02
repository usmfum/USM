// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/MedianOracle.sol";

contract GasMeasuredMedianOracle is MedianOracle, GasMeasuredOracle("median") {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        MedianOracle(chainlinkAggregator, compoundView,
                     uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function cacheLatestPrice() public override(Oracle, MedianOracle) returns (uint price) {
        price = MedianOracle.cacheLatestPrice();
    }
}
