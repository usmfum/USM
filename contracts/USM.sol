pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOracle.sol";

contract USM is ERC20, Ownable {
    using SafeMath for uint;

    address oracle;
    uint public ethPool;

    constructor(address _oracle) public ERC20("Minimal USD", "USM") {
        oracle = _oracle;
        ethPool = 0;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function mint() external payable returns (uint) {
        require(msg.value > 0, "Must send Ether to mint");
        uint usmAmount = _ethToUsm(msg.value);
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmAmount);
        return usmAmount;
    }

    function burn(uint _usmAmount) external {
        uint ethAmount = _usmToEth(_usmAmount);
        ethPool = ethPool.sub(ethAmount);
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethAmount);
    }

    function _ethToUsm(uint _ethAmount) internal view returns (uint) {
        (uint usdPrice, uint decimalShift) = _oracleData();
        return usdPrice.mul(_ethAmount).div(10**decimalShift);
    }

    function _usmToEth(uint _usmAmount) internal view returns (uint) {
        (uint usdPrice, uint decimalShift) = _oracleData();
        return (_usmAmount.mul(10**decimalShift)).div(usdPrice);
    }

    function _oracleData() internal view returns (uint, uint) {
        return (
            IOracle(oracle).latestPrice(),
            IOracle(oracle).decimalShift()
        );
    }
}