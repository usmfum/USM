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

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        uint gasStart = gasleft();
        (price, updateTime) = measuredOracle.latestPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.latestPrice() cost: ", gasStart - gasEnd);
    }

    function refreshPrice() public virtual override returns (uint price, uint updateTime) {
        uint gasStart = gasleft();
        (price, updateTime) = measuredOracle.refreshPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.refreshPrice() cost: ", gasStart - gasEnd);
    }
}
