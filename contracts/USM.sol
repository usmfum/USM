// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USMTemplate.sol";
import "./oracles/ChainlinkOracle.sol";
import "./oracles/CompoundOpenOracle.sol";
import "./oracles/OurUniswapV2TWAPOracle.sol";

contract USM is USMTemplate, ChainlinkOracle {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        USMTemplate()
        ChainlinkOracle(chainlinkAggregator) {}

    function cacheLatestPrice() public virtual override returns (uint price) {
        price = super.cacheLatestPrice();
    }
}
