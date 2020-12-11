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

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        USM(chainlinkAggregator, compoundView,
            uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function setPrice(uint p) public override {
        savedPrice = p;
    }

    function cacheLatestPrice() public override(Oracle, USM) returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.cacheLatestPrice();
    }

    function latestPrice() public override view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
