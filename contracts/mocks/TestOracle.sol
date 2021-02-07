// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SettableOracle.sol";
import "../Ownable.sol";

contract TestOracle is SettableOracle, Ownable {
    constructor(uint p) {
        setPrice(p);
    }

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        return (savedPrice, savedUpdateTime);
    }
}
