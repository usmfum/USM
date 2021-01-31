// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./SettableOracle.sol";
import "../oracles/ChainlinkOracle.sol";

/**
 * @title MockChainlinkOracle
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice A ChainlinkOracle whose price we can override.  Testing purposes only!
 */
contract MockChainlinkOracle is ChainlinkOracle, SettableOracle {
    uint public savedPrice;
    uint public savedUpdateTime;

    constructor(AggregatorV3Interface aggregator_) public ChainlinkOracle(aggregator_) {}

    function setPrice(uint p) public override {
        savedPrice = p;
        savedUpdateTime = block.timestamp;
    }

    function refreshPrice() public override returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.refreshPrice();
    }

    function latestPrice() public override(ChainlinkOracle, Oracle) view returns (uint price, uint updateTime) {
        (price, updateTime) = (savedPrice != 0) ? (savedPrice, savedUpdateTime) : super.latestPrice();
    }
}
