// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/ChainlinkOracle.sol";

contract GasMeasuredChainlinkOracle is ChainlinkOracle, GasMeasuredOracle("chainlink") {
    constructor(address chainlinkAggregator) public ChainlinkOracle(chainlinkAggregator) {}
}
