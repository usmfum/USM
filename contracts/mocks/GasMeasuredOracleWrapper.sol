// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../oracles/Oracle.sol";
import "hardhat/console.sol";

contract GasMeasuredOracleWrapper is Oracle {

    Oracle public immutable measuredOracle;
    string public oracleName;

    constructor(Oracle oracle, string memory name) {
        measuredOracle = oracle;
        oracleName = name;
    }

    function latestPrice() public virtual override view returns (uint price) {
        uint gasStart = gasleft();
        price = measuredOracle.latestPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.latestPrice() cost: ", gasStart - gasEnd);
    }
}
