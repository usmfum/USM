pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOracle.sol";

contract USM is ERC20, Ownable {
    using SafeMath for uint;

    address oracle;
    uint public ethPool;

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public ERC20("Minimal USD", "USM") {
        oracle = _oracle;
        ethPool = 0;
    }

    /**
     * @dev Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        uint usmAmount = _ethToUsm(msg.value);
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmAmount);
    }

    /**
     * @dev Burn USM for ETH.
     *
     * @param _usmAmount Amount of USM to burn.
     */
    function burn(uint _usmAmount) external {
        uint ethAmount = _usmToEth(_usmAmount);
        ethPool = ethPool.sub(ethAmount);
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethAmount);
    }

    /**
     * @dev Set the price oracle. Only Owner.
     *
     * @param _oracle Address of the oracle.
     */
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    /**
     * @dev Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param _ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function _ethToUsm(uint _ethAmount) internal view returns (uint) {
        require(_ethAmount > 0, "Eth Amount must be more than 0");
        (uint usdPrice, uint decimalShift) = _oracleData();
        return usdPrice.mul(_ethAmount).div(10**decimalShift);
    }

    /**
     * @dev Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param _usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function _usmToEth(uint _usmAmount) internal view returns (uint) {
        require(_usmAmount > 0, "USM Amount must be more than 0");
        (uint usdPrice, uint decimalShift) = _oracleData();
        return (_usmAmount.mul(10**decimalShift)).div(usdPrice);
    }

    /**
     * @dev Retrieve the latest price and decimal shift of the
     * price oracle.
     *
     * @return (latest price, decimal shift)
     */
    function _oracleData() internal view returns (uint, uint) {
        return (
            IOracle(oracle).latestPrice(),
            IOracle(oracle).decimalShift()
        );
    }
}