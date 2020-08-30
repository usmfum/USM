// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "./IOracle.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";

contract ChainlinkOracle is IOracle{

    address oracle;
    uint decShift;

    /**
     * @notice Ropsten Details:
     * address: 0x30B5068156688f818cEa0874B580206dFe081a03
     * decShift: 8
     */
    constructor(address _oracle, uint _decShift) public {
        oracle = _oracle;
        decShift = _decShift;
    }

    function latestPrice() external override view returns (uint) {
        return uint(AggregatorInterface(oracle).latestAnswer());
    }

    function decimalShift() external override view returns (uint) {
        return decShift;
    }
}