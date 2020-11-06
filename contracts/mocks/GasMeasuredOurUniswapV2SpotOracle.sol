// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/OurUniswapV2SpotOracle.sol";

contract GasMeasuredOurUniswapV2SpotOracle is OurUniswapV2SpotOracle, GasMeasuredOracle("uniswap") {
    constructor(address pair, bool tokensInReverseOrder, uint scaleFactor) public
        OurUniswapV2SpotOracle(pair, tokensInReverseOrder, scaleFactor) {}
}
