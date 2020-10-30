// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./IOracle.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@nomiclabs/buidler/console.sol";


contract ChainlinkOracle is IOracle{

    AggregatorV3Interface public oracle;
    uint public override decimalShift;

    /**
     * @notice Ropsten Details:
     * address: 0x30B5068156688f818cEa0874B580206dFe081a03
     * decShift: 8
     */
    constructor(address oracle_, uint shift) public {
        oracle = AggregatorV3Interface(oracle_);
        decimalShift = shift;
    }

    function latestPrice() external override view returns (uint) {
        (, int price,,,) = oracle.latestRoundData();
        return uint(price); // TODO: Cast safely
    }
}
