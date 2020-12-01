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
    uint private constant NUM_UNISWAP_PAIRS = 3;

    uint private savedPrice;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair[NUM_UNISWAP_PAIRS] memory uniswapPairs,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens0Decimals,
        uint[NUM_UNISWAP_PAIRS] memory uniswapTokens1Decimals,
        bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder
    ) public
        USM(chainlinkAggregator, compoundView,
            uniswapPairs, uniswapTokens0Decimals, uniswapTokens1Decimals, uniswapTokensInReverseOrder) {}

    function setPrice(uint p) public override {
        savedPrice = p;
    }

    function cacheLatestPrice() public override(Oracle, USM) returns (uint price) {
        USM.cacheLatestPrice();
        price = latestPrice();
    }

    function latestPrice() public override view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
