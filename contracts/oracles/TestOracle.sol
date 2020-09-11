pragma solidity ^0.6.7;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOracle is IOracle, Ownable{
    using SafeMath for uint;

    uint public override latestPrice;
    uint public override decimalShift;

    constructor(uint price, uint shift) public {
        latestPrice = price;
        decimalShift = shift;
        // 25000, 2 = $250.00
    }

    function setPrice(uint price) external onlyOwner {
        latestPrice = price;
    }
}