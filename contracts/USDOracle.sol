pragma solidity ^0.6.7;

contract USDOracle {

    uint price;

    constructor() public {
        price = 200*10**2;
    }

    function latestPrice() public view returns (uint) {
        return price;
    }
}