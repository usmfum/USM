pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "./oracles/IOracle.sol";
import "@nomiclabs/buidler/console.sol";
import "./FUM.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff)
 */
contract USM is ERC20 {
    using SafeMath for uint;
    using WadMath for uint;

    uint constant WAD = 10 ** 18;
    uint constant MINT_FEE = WAD / 1000; // 0.1%
    uint constant BURN_FEE = WAD / 200; // 0.5%

    address oracle;
    address fum;
    uint public ethPool;

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public ERC20("Minimal USD", "USM") {
        oracle = _oracle;
        ethPool = 0;
        fum = address(new FUM());
        console.log(_oracle);
        console.log(fum);
    }

    /**
     * @notice Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        uint usmAmount = _ethToUsm(msg.value);
        uint usmMinusFee = usmAmount.sub(usmAmount.wadMul(MINT_FEE));
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
        uint ethMinusFee = ethAmount.sub(ethAmount.wadMul(BURN_FEE));
        ethPool = ethPool.sub(ethMinusFee);
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethMinusFee);
    }

    // // TODO: fund depending on ethPriceOfFum
    // function fund() external payable{
    //     console.log(divFixed(msg.value, ethPriceOfFum()));
    // }
    // // TODO: defund depending on ethPriceOfFum

    /**
     * @notice Calculate the price of FUM in ETH using this ethBuffer
     * and the current total supply of FUM.
     *
     * @return ETH price of FUM in UNIT
     */
    function ethPriceOfFum() public view returns (uint){
        uint fumTotalSupply = FUM(fum).totalSupply();
        if (fumTotalSupply == 0) {
            fumTotalSupply = 1;
        }
        return ethBuffer().wadDiv(fumTotalSupply);
    }

    /**
     * @notice Calculate the buffer between the ETH in the pool and the value
     * of the totalSupply of USM
     *
     * @return Amount of ETH buffer in WAD
     */
    function ethBuffer() public view returns (uint){
        return ethPool.sub(_usmToEth(totalSupply()));
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
        // If divFixed is fed two integers, returns their division as a fixed point number
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
     * @return price in UNIT
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(IOracle(oracle).decimalShift(), UNIT) function.
        return IOracle(oracle).latestPrice().mul(WAD).div(10 ** IOracle(oracle).decimalShift());
    }
}