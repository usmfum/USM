// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/OurUniswapV2SpotOracle.sol";

contract GasMeasuredOurUniswapV2SpotOracle is OurUniswapV2SpotOracle, GasMeasuredOracle("uniswapSpot") {
    constructor(IUniswapV2Pair pair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder) public
        OurUniswapV2SpotOracle(pair, token0Decimals, token1Decimals, tokensInReverseOrder) {}
}
