// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/CompositeOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockCompositeOracle is CompositeOracle, GasMeasuredOracle("composite") {
    constructor(IOracle[3] memory oracles_, uint decimalShift_) public
        CompositeOracle(oracles_, decimalShift_) {}
}
