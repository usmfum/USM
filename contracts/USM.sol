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

    uint constant UNIT = 1000000000000000000000000000; // 10**27, MakerDAO's RAY
    uint constant MINT_FEE = UNIT / 1000; // 0.1%
    uint constant BURN_FEE = UNIT / 200; // 0.5%

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
     * @notice Multiplies x and y, assuming they are both fixed point with 27 digits.
     */
    function mulFixed(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mul(y).div(UNIT);
    }

    /**
     * @notice Divides x by y, assuming they are both fixed point with 27 digits.
     */
    function divFixed(uint256 x, uint256 y) internal pure returns (uint256) {
        return x.mul(UNIT).div(y);
    }

    /**
     * @notice Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        uint usmAmount = _ethToUsm(msg.value);
        uint usmMinusFee = usmAmount.sub(mulFixed(usmAmount, MINT_FEE));
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmMinusFee);
    }

    /**
     * @notice Burn USM for ETH.
     *
     * @param _usmAmount Amount of USM to burn.
     */
    function burn(uint _usmAmount) external {
        uint ethAmount = _usmToEth(_usmAmount);
        uint ethMinusFee = ethAmount.sub(mulFixed(ethAmount, BURN_FEE));
        ethPool = ethPool.sub(ethMinusFee);
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethMinusFee);
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio in UNIT.
     */
    function debtRatio() external view returns (uint) {
        if (ethPool == 0) {
            return 0;
        }
        return divFixed(totalSupply(), _ethToUsm(ethPool));
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
        return mulFixed(_oraclePrice(), _ethAmount);
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
        return divFixed(_usmAmount, _oraclePrice());
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price in UNIT
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(IOracle(oracle).decimalShift(), UNIT) function.
        return IOracle(oracle).latestPrice().mul(UNIT).div(10 ** IOracle(oracle).decimalShift());
    }
}