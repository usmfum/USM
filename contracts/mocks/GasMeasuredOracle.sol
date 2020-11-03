// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../oracles/Oracle.sol";
import "@nomiclabs/buidler/console.sol";

abstract contract GasMeasuredOracle is Oracle {
    using SafeMath for uint;

    string internal oracleName;

    constructor(string memory name) public {
        oracleName = name;
    }

    function latestPriceWithGas() public virtual view returns (uint price) {
        uint gasStart = gasleft();
        price = this.latestPrice();
        uint gasEnd = gasleft();
        console.log("        ", oracleName, "oracle.latestPrice() cost: ", gasStart.sub(gasEnd));
    }
}
