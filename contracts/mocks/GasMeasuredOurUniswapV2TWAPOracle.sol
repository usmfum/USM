// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/OurUniswapV2TWAPOracle.sol";

contract GasMeasuredOurUniswapV2TWAPOracle is OurUniswapV2TWAPOracle, GasMeasuredOracle("uniswapTWAP") {
    constructor(IUniswapV2Pair pair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder) public
        OurUniswapV2TWAPOracle(pair, token0Decimals, token1Decimals, tokensInReverseOrder) {}

    function cacheLatestPrice() public override(Oracle, OurUniswapV2TWAPOracle) returns (uint price) {
        price = OurUniswapV2TWAPOracle.cacheLatestPrice();
    }
}
