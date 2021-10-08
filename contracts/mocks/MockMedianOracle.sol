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
        IUniswapV3Pool uniswapPool1, uint uniswapTokenToPrice1, int uniswapDecimals1,
        IUniswapV3Pool uniswapPool2, uint uniswapTokenToPrice2, int uniswapDecimals2
    )
        MedianOracle(chainlinkAggregator,
            uniswapPool1, uniswapTokenToPrice1, uniswapDecimals1,
            uniswapPool2, uniswapTokenToPrice2, uniswapDecimals2) {}

    function latestPrice() public override(MedianOracle, Oracle) view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
