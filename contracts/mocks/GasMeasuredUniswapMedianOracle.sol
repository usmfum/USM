// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/UniswapMedianOracle.sol";

contract GasMeasuredUniswapMedianOracle is UniswapMedianOracle, GasMeasuredOracle("uniswapMedian") {
    uint private constant NUM_SOURCE_ORACLES = 3;

    constructor(address[NUM_SOURCE_ORACLES] memory pairs,
                bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder,
                uint[NUM_SOURCE_ORACLES] memory scaleFactors) public
        UniswapMedianOracle(pairs, tokensInReverseOrder, scaleFactors) {}
}
