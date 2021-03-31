// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./Oracle.sol";

/**
 * @title ChainlinkOracle
 */
contract ChainlinkOracle is Oracle {

    uint public constant CHAINLINK_SCALE_FACTOR = 1e10; // Since Chainlink has 8 dec places, and latestPrice() needs 18

    AggregatorV3Interface public immutable chainlinkAggregator;

    constructor(AggregatorV3Interface aggregator_)
    {
        chainlinkAggregator = aggregator_;
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        int rawPrice;
        (, rawPrice,, updateTime,) = chainlinkAggregator.latestRoundData();
        require(rawPrice > 0, "Chainlink price <= 0");
        price = uint(rawPrice) * CHAINLINK_SCALE_FACTOR;
    }
}
