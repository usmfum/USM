// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SettableOracle.sol";
import "../oracles/MedianOracle.sol";

/**
 * @title MockMedianOracle
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice A MedianOracle which also, for testing purposes, has SettableOracle functionality.
 */
contract MockMedianOracle is MedianOracle, SettableOracle {
    constructor(
        AggregatorV3Interface chainlinkAggregator,
        CompoundUniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapV2Pair, uint uniswapTokenToUse, int uniswapTokenDecimals
    )
        MedianOracle(chainlinkAggregator, compoundView,
            uniswapV2Pair, uniswapTokenToUse, uniswapTokenDecimals) {}

    function refreshPrice() public override(MedianOracle, Oracle) returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.refreshPrice();
    }

    function latestPrice() public override(MedianOracle, Oracle) view returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.latestPrice();
    }
}
