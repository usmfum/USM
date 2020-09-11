pragma solidity ^0.6.7;

import "./IOracle.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";

contract ChainlinkOracle is IOracle{

    address public oracle;
    uint public override decimalShift;

    /**
     * @notice Ropsten Details:
     * address: 0x30B5068156688f818cEa0874B580206dFe081a03
     * decShift: 8
     */
    constructor(address oracle_, uint shift) public {
        oracle = oracle_;
        decimalShift = shift;
    }

    function latestPrice() external override view returns (uint) {
        return uint(AggregatorInterface(oracle).latestAnswer());
    }
}