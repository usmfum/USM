// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "../USM.sol";

/**
 * @title MockUSM
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice Like USM, but allows latestPrice() to be set for testing purposes
 */
contract MockUSM is USM {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    uint private savedPrice;

    constructor(address eth, address chainlinkAggregator, address compoundView,
                address[NUM_UNISWAP_PAIRS] memory uniswapPairs, bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder,
                uint[NUM_UNISWAP_PAIRS] memory uniswapScaleFactors) public
        USM(eth, chainlinkAggregator, compoundView, uniswapPairs, uniswapTokensInReverseOrder, uniswapScaleFactors) {}

    function setPrice(uint p) public {
        savedPrice = p;
    }

    function latestPrice() public override view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
