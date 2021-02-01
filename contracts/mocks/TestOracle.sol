// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SettableOracle.sol";
import "../Ownable.sol";

contract TestOracle is SettableOracle, Ownable {
    uint internal savedPrice;
    uint internal savedUpdateTime;

    constructor(uint p) {
        setPrice(p);
    }

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        return (savedPrice, savedUpdateTime);
    }

    function setPrice(uint p) public override {
        savedPrice = p;
        savedUpdateTime = block.timestamp;
    }
}
