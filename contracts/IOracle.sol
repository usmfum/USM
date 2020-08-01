pragma solidity ^0.6.7;

interface IOracle {
    function latestPrice() external view returns (uint);
    function decimalShift() external view returns (uint);
}