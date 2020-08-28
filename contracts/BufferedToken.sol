pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "./oracles/IOracle.sol";

contract BufferedToken is ERC20 {
    using SafeMath for uint;
    using WadMath for uint;

    uint constant WAD = 10 ** 18;

    uint public ethPool;
    address oracle;

    constructor(address _oracle, string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        oracle = _oracle;
        ethPool = 0;
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public view returns (int) {
        int buffer = int(ethPool) - int(_usmToEth(totalSupply()));
        require(buffer <= int(ethPool), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        if (ethPool == 0) {
            return 0;
        }
        return totalSupply().wadDiv(_ethToUsm(ethPool));
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
        return _oraclePrice().wadMul(_ethAmount);
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
        return _usmAmount.wadDiv(_oraclePrice());
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(IOracle(oracle).decimalShift(), UNIT) function.
        return IOracle(oracle).latestPrice().mul(WAD).div(10 ** IOracle(oracle).decimalShift());
    }

}