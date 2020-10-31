// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "../oracles/ChainlinkOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockChainlinkOracle is ChainlinkOracle, GasMeasuredOracle("chainlink") {
    constructor(address oracle_, uint decimalShift_) public ChainlinkOracle(oracle_, decimalShift_) {}
}
