// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/CompoundOpenOracle.sol";

contract GasMeasuredCompoundOpenOracle is CompoundOpenOracle, GasMeasuredOracle("compound") {
    constructor(address compoundView) public CompoundOpenOracle(compoundView) {}
}
