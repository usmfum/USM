// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./TestOracle.sol";
import "../USMTemplate.sol";

/**
 * @title MockTestOracleUSM
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice A USMTemplate implementation for testing that uses only a simple TestOracle, no actual external source oracle
 */
contract MockTestOracleUSM is USMTemplate, TestOracle {
    constructor(uint price) public USMTemplate() TestOracle(price) {}

    function refreshPrice() public virtual override(USMTemplate, Oracle) returns (uint price, uint updateTime) {
        (price, updateTime) = super.refreshPrice();
    }

    function latestPrice() public virtual override(USMTemplate, TestOracle) view returns (uint price, uint updateTime) {
        (price, updateTime) = super.latestPrice();
    }
}
