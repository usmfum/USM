// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../oracles/Oracle.sol";
import "@nomiclabs/buidler/console.sol";

contract GasMeasuredOracleWrapper is Oracle {
    using SafeMath for uint;

    Oracle internal immutable measuredOracle;
    string internal oracleName;

    constructor(Oracle oracle, string memory name) public {
        measuredOracle = oracle;
        oracleName = name;
    }

    function latestPrice() public virtual override view returns (uint price) {
        uint gasStart = gasleft();
        price = measuredOracle.latestPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.latestPrice() cost: ", gasStart.sub(gasEnd));
    }

    function cacheLatestPrice() public virtual override returns (uint price) {
        uint gasStart = gasleft();
        price = measuredOracle.cacheLatestPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.cacheLatestPrice() cost: ", gasStart.sub(gasEnd));
    }
}
