// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../oracles/IOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract SettableOracle is IOracle {
    IOracle internal baseOracle;
    uint internal storedPrice;

    constructor(IOracle _baseOracle) public {
        baseOracle = _baseOracle;
    }

    function latestPrice() external override view returns (uint) {
        return (storedPrice != 0 ? storedPrice : baseOracle.latestPrice());
    }

    function decimalShift() external virtual override view returns (uint) {
        return baseOracle.decimalShift();
    }

    function setPrice(uint price) public {
        storedPrice = price;
    }
}
