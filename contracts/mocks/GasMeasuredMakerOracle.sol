// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "../oracles/MakerOracle.sol";

contract GasMeasuredMakerOracle is MakerOracle, GasMeasuredOracle("maker") {
    constructor(address medianizer) public MakerOracle(medianizer) {}
}
