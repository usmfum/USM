pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "@nomiclabs/buidler/console.sol";
import "./oracles/IOracle.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is ERC20 {
    using SafeMath for uint;
    using WadMath for uint;

    address public oracle;
    FUM public fum;
    uint public latestFumPrice;                               // default 0

    uint public constant WAD = 10 ** 18;
    uint constant public MIN_ETH_AMOUNT = WAD / 1000;         // 0.001 ETH
    uint constant public MIN_BURN_AMOUNT = WAD;               // 1 USM
    uint constant public MAX_DEBT_RATIO = WAD * 8 / 10;       // 80%

    event LatestFumPriceChanged(uint previous, uint latest);

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public ERC20("Minimal USD", "USM") {
        fum = new FUM();
        oracle = _oracle;
        _setLatestFumPrice();
    }

    /** EXTERNAL FUNCTIONS **/

    /**
     * @notice Mint ETH for USM with checks and asset transfers. Uses msg.value as the ETH deposit.
     * @return USM minted
     */
    function mint() external payable returns (uint) {
        require(msg.value > MIN_ETH_AMOUNT, "0.001 ETH minimum");
        require(fum.totalSupply() > 0, "Fund before minting");
        uint usmMinted = ethToUsm(msg.value);
        _mint(msg.sender, usmMinted);
        // set latest fum price
        _setLatestFumPrice();
        return usmMinted;
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     *
     * @param _usmToBurn Amount of USM to burn.
     * @return ETH sent
     */
    function burn(uint _usmToBurn) external returns (uint) {
        require(_usmToBurn >= MIN_BURN_AMOUNT, "1 USM minimum");
        // uint ethToSend = _burn(_usmToBurn);
        uint ethToSend = usmToEth(_usmToBurn);
        _burn(msg.sender, _usmToBurn);
        Address.sendValue(msg.sender, ethToSend);
        // set latest fum price
        _setLatestFumPrice();
        require(debtRatio() <= WAD, "Debt ratio too high");
        return (ethToSend);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     */
    function fund() external payable {
        require(msg.value > MIN_ETH_AMOUNT, "0.001 ETH minimum");
        if(debtRatio() > MAX_DEBT_RATIO){
            // calculate the ETH needed to bring debt ratio to suitable levels
            uint ethNeeded = usmToEth(totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(address(this).balance).add(1); //+ 1 to tip it over the edge
            if (msg.value >= ethNeeded) { // Split into two fundings at different prices
                _fund(msg.sender, ethNeeded);
                _fund(msg.sender, msg.value.sub(ethNeeded));
                return;
            } // Otherwise continue for funding the total at a single price
        }
        _fund(msg.sender, msg.value);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH
     * from the pool
     */
    function defund(uint _fumAmount) external {
        require(_fumAmount >= MIN_BURN_AMOUNT, "1 FUM minimum");
        uint _fumPrice = fumPrice();
        uint ethAmount = _fumAmount.wadMul(_fumPrice);
        fum.burn(msg.sender, _fumAmount);
        Address.sendValue(msg.sender, ethAmount);
        // set latest fum price
        _setLatestFumPrice();
        require(debtRatio() <= MAX_DEBT_RATIO,
            "Max debt ratio breach");
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public view returns (int) {
        int buffer = int(address(this).balance) - int(usmToEth(totalSupply()));
        require(buffer <= int(address(this).balance), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        if (address(this).balance == 0) {
            return 0;
        }
        return totalSupply().wadDiv(ethToUsm(address(this).balance));
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and ETH buffer
     */
    function fumPrice() public view returns (uint) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToEth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        int buffer = ethBuffer();
        // if we're underwater, use the last fum price
        if (buffer <= 0 || debtRatio() > MAX_DEBT_RATIO) {
            return latestFumPrice;
        }
        return uint(buffer).wadDiv(fumTotalSupply);
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param _ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function ethToUsm(uint _ethAmount) public view returns (uint) {
        if (_ethAmount == 0) {
            return 0;
        }
        return _oraclePrice().wadMul(_ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param _usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function usmToEth(uint _usmAmount) public view returns (uint) {
        if (_usmAmount == 0) {
            return 0;
        }
        return _usmAmount.wadDiv(_oraclePrice());
    }

    /** INTERNAL FUNCTIONS */

    /**
     * @notice Set the latest fum price. Emits a LatestFumPriceChanged event.
     */
    function _setLatestFumPrice() internal {
        uint previous = latestFumPrice;
        latestFumPrice = fumPrice();
        emit LatestFumPriceChanged(previous, latestFumPrice);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function _fund(address to, uint ethIn) internal {
        uint _fumPrice = fumPrice();
        uint fumOut = ethIn.wadDiv(_fumPrice);
        fum.mint(to, fumOut);
        _setLatestFumPrice();
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