// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/CompoundOpenOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockCompoundOpenOracle is CompoundOpenOracle, GasMeasuredOracle("compound") {
    constructor(address oracle_, uint decimalShift_) public CompoundOpenOracle(oracle_, decimalShift_) {}
}
