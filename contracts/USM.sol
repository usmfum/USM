pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IOracle.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff)
 */
contract USM is ERC20 {
    using SafeMath for uint;

    // 0.1% (10 parts per 10,000)
    uint constant MINT_FEE = 10;
    // 0.5%; (50 parts per 10,000)
    uint constant BURN_FEE = 50;
    uint constant PERCENTAGE_BASE = 10000;

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
     * @notice Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        uint usmAmount = _applyFee(_ethToUsm(msg.value), MINT_FEE);
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmAmount);
    }

    /**
     * @notice Burn USM for ETH.
     *
     * @param _usmAmount Amount of USM to burn.
     */
    function burn(uint _usmAmount) external {
        uint ethAmount = _applyFee(_usmToEth(_usmAmount), BURN_FEE);
        ethPool = ethPool.sub(ethAmount);
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethAmount);
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio decimal percentage *(10**decimals()). For example, 100%
     * is denoted as 1,000,000,000,000,000,000 (1 with 18 zeros).
     */
    function debtRatio() external view returns (uint) {
        return _debtRatio(ethPool, totalSupply());
    }

    /**
     * @notice Calculate debt ratio of an Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @param _ethPool Amount of Eth in the pool.
     * @param _usmOutstanding Amount of USM in total supply.
     * @return Debt ratio decimal percentage *(10**decimals()). For example, 100%
     * is denoted as 1,000,000,000,000,000,000 (1 with 18 zeros).
     */
    function _debtRatio(uint _ethPool, uint _usmOutstanding) internal view returns (uint) {
        if (_ethPool == 0) {
            return 0;
        }
        return _usmOutstanding.mul(10**uint(decimals())).div(_ethToUsm(_ethPool));
    }

    /**
     * @notice Apply fees to a number, the result being the number, minus the
     * percentage fee.
     *
     * @param _number The amount that the fee is being applied to
     * @param _feePercentage Percentage fee to be subtracted from the number
     * in parts per 10,000.
     * @return The result of the _number minus the percentage fee.
     */
    function _applyFee(uint _number, uint _feePercentage) internal pure returns (uint) {
        uint result = _number.sub((_number.mul(_feePercentage)).div(PERCENTAGE_BASE));
        require(result < _number, "Fee must make the result smaller");
        return result;
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
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
     * @notice Convert USM amount to ETH using the latest price of USM
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
     * @notice Retrieve the latest price and decimal shift of the
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