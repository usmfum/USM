// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/MakerOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockMakerOracle is MakerOracle, GasMeasuredOracle("maker") {
    constructor(address medianizer_, uint decimalShift_) public MakerOracle(medianizer_, decimalShift_) {}
}
