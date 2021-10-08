// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SettableOracle.sol";

contract TestOracle is SettableOracle {
    constructor(uint p) {
        setPrice(p);
    }

    function latestPrice() public virtual override view returns (uint price) {
        return savedPrice;
    }
}
