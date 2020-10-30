// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/OurUniswapV2SpotOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockOurUniswapV2SpotOracle is OurUniswapV2SpotOracle, GasMeasuredOracle("uniswap") {
    constructor(address pair_, bool areTokensInReverseOrder_, uint decimalShift_, uint scalePriceBy_) public
        OurUniswapV2SpotOracle(pair_, areTokensInReverseOrder_, decimalShift_, scalePriceBy_) {}
}
