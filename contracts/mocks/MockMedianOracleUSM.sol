// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./MockMedianOracle.sol";
import "../USMTemplate.sol";

/**
 * @title MockMedianOracleUSM
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice Like USM, but for test purposes using a (SettableOracle) MockMedianOracle, rather than a production MedianOracle.
 */
contract MockMedianOracleUSM is MockMedianOracle, USMTemplate {
    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        USMTemplate()
        MockMedianOracle(chainlinkAggregator, compoundView,
                         uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function refreshPrice() public virtual override(MockMedianOracle, USMTemplate) returns (uint price, uint updateTime) {
        (price, updateTime) = super.refreshPrice();
    }

    function latestPrice() public virtual override(MockMedianOracle, USMTemplate) view returns (uint price, uint updateTime) {
        (price, updateTime) = super.latestPrice();
    }
}
