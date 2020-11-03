// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/CompositeOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockCompositeOracle is CompositeOracle, GasMeasuredOracle("composite") {
    constructor(
        address chainlinkOracle_, uint chainlinkShift_,
        address compoundOracle_, uint compoundShift_,
        address uniswapPair_, bool areTokensInReverseOrder_, uint uniswapShift_, uint scalePriceBy_,
        uint decimalShift_)
    public CompositeOracle(
        chainlinkOracle_, chainlinkShift_,
        compoundOracle_, compoundShift_,
        uniswapPair_, areTokensInReverseOrder_, uniswapShift_, scalePriceBy_,
        decimalShift_)
    {}
}
