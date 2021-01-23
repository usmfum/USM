// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./Oracle.sol";

/**
 * @title ChainlinkOracle
 */
contract ChainlinkOracle is Oracle {

    uint private constant SCALE_FACTOR = 10 ** 10;  // Since Chainlink has 8 dec places, and latestPrice() needs 18

    AggregatorV3Interface public aggregator;

    constructor(AggregatorV3Interface aggregator_) public
    {
        aggregator = aggregator_;
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime) = latestChainlinkPrice();
    }

    function latestChainlinkPrice() public view returns (uint price, uint updateTime) {
        int rawPrice;
        (, rawPrice,, updateTime,) = aggregator.latestRoundData();
        price = uint(rawPrice) * SCALE_FACTOR; // TODO: Cast safely
    }
}
