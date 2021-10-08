// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SettableOracle.sol";
import "../oracles/ChainlinkOracle.sol";

/**
 * @title MockChainlinkOracle
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice A ChainlinkOracle whose price we can override.  Testing purposes only!
 */
contract MockChainlinkOracle is ChainlinkOracle, SettableOracle {
    constructor(AggregatorV3Interface aggregator_) ChainlinkOracle(aggregator_) {}

    function latestPrice() public override(ChainlinkOracle, Oracle) view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.latestPrice();
    }
}
