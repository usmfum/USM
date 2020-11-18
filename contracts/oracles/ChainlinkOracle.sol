// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./Oracle.sol";

/**
 * @title ChainlinkOracle
 */
contract ChainlinkOracle is Oracle {
    using SafeMath for uint;

    uint private constant SCALE_FACTOR = 10 ** 10;  // Since Chainlink has 8 dec places, and latestPrice() needs 18

    AggregatorV3Interface private aggregator;

    constructor(address aggregator_) public
    {
        aggregator = AggregatorV3Interface(aggregator_);
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price) {
        price = latestChainlinkPrice();
    }

    function latestChainlinkPrice() public view returns (uint price) {
        (, int rawPrice,,,) = aggregator.latestRoundData();
        price = uint(rawPrice).mul(SCALE_FACTOR); // TODO: Cast safely
    }
}
