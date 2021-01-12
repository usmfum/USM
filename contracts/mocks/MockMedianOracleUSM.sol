// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./SettableOracle.sol";
import "../USM.sol";

/**
 * @title MockMedianOracleUSM
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice Like USM (so, also inheriting MedianOracle), but allows latestPrice() to be set for testing purposes
 */
contract MockMedianOracleUSM is USM, SettableOracle {
    uint private savedPrice;
    uint private savedUpdateTime;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        USM(chainlinkAggregator, compoundView,
            uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function setPrice(uint p) public override {
        savedPrice = p;
        savedUpdateTime = now;
    }

    function refreshPrice() public override(Oracle, USM) returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.refreshPrice();
    }

    function latestPrice() public override view returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.latestPrice();
    }
}
