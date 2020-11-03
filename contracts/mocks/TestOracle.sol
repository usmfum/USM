// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./GasMeasuredOracle.sol";
import "./SettableOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOracle is GasMeasuredOracle("test"), SettableOracle, Ownable {
    uint internal savedPrice;

    constructor(uint p) public {
        setPrice(p);
    }

    function latestPrice() public override view returns (uint) {
        return savedPrice;
    }

    function setPrice(uint p) public override {
        savedPrice = p;
    }
}
