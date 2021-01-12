// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./SettableOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOracle is SettableOracle, Ownable {
    uint internal savedPrice;
    uint internal savedUpdateTime;

    constructor(uint p) public {
        setPrice(p);
    }

    function latestPrice() public override view returns (uint price, uint updateTime) {
        return (savedPrice, savedUpdateTime);
    }

    function setPrice(uint p) public override {
        savedPrice = p;
        savedUpdateTime = now;
    }
}
