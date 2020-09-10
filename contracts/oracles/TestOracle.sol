pragma solidity ^0.6.7;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestOracle is IOracle, Ownable{
    using SafeMath for uint;

    uint price;
    uint decShift;

    constructor(uint price_, uint decShift_) public {
        price = price_;
        decShift = decShift_;
        // 25000, 2 = $250.00
    }

    function latestPrice() external override view returns (uint) {
        return price;
    }

    function decimalShift() external override view returns (uint) {
        return decShift;
    }

    function setPrice(uint _newPrice) external onlyOwner {
        price = _newPrice;
    }
}