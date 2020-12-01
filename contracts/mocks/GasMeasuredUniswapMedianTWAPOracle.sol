// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/UniswapMedianTWAPOracle.sol";

contract GasMeasuredUniswapMedianTWAPOracle is UniswapMedianTWAPOracle, GasMeasuredOracle("uniswapMedianTWAP") {
    uint private constant NUM_SOURCE_ORACLES = 3;

    constructor(
        IUniswapV2Pair[NUM_SOURCE_ORACLES] memory pairs,
        uint[NUM_SOURCE_ORACLES] memory tokens0Decimals,
        uint[NUM_SOURCE_ORACLES] memory tokens1Decimals,
        bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder
    ) public
        UniswapMedianTWAPOracle(pairs, tokens0Decimals, tokens1Decimals, tokensInReverseOrder) {}

    function cacheLatestPrice() public override(Oracle, UniswapMedianTWAPOracle) returns (uint price) {
        price = UniswapMedianTWAPOracle.cacheLatestPrice();
    }
}
