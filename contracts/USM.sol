pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IOracle.sol";

contract USM is ERC20 {
    using Address for address;
    using SafeMath for uint;

    address oracle;
    uint public ethPool;

    constructor(address _oracle) public ERC20("Minimal USD", "USM") {
        oracle = _oracle;
        ethPool = 0;
    }

    function mint() external payable returns (uint) {
        require(msg.value > 0, "Must send Ether to mint");
        uint usdPrice = IOracle(oracle).latestPrice();
        uint decimalShift = IOracle(oracle).decimalShift();
        uint usmAmount = usdPrice.mul(msg.value).div(10**decimalShift);
        ethPool += msg.value;
        _mint(msg.sender, usmAmount);
        return usmAmount;
    }
}