pragma solidity ^0.6.7;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "./BufferedToken.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "@nomiclabs/buidler/console.sol";


/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is BufferedToken {
    using SafeMath for uint;
    using Math for uint;
    using WadMath for uint;

    uint constant public MIN_ETH_AMOUNT = WAD / 1000;         // 0.001 ETH
    uint constant public MIN_BURN_AMOUNT = WAD;               // 1 USM
    uint constant public MAX_DEBT_RATIO = WAD 9 / 10; // 90%

    FUM public fum;
    uint public latestFumPrice;

    event LatestFumPriceChanged(uint previous, uint latest);

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public BufferedToken(_oracle, "Minimal USD", "USM") {
        _setLatestFumPrice(MIN_ETH_AMOUNT);
        fum = new FUM();
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and ETH buffer
     */
    function fumPrice() public view returns (uint) {
        int buffer = ethBuffer();
        // if we're underwater, use the last fum price
        if (buffer <= 0 || debtRatio() > MAX_DEBT_RATIO) {
            return latestFumPrice;
        }

        uint fumTotalSupply = fum.totalSupply().max(WAD); // fumTotalSupply is floored at WAD
        return uint(buffer).wadDiv(fumTotalSupply);
    }

    /**
     * @notice Mint ETH for USM with checks and asset transfers. Uses msg.value as the ETH deposit.
     * @return USM minted
     */
    function mint() external payable returns (uint) {
        require(msg.value > MIN_ETH_AMOUNT, "Must deposit more than 0.001 ETH");
        uint usmMinted = _mint(msg.value);
        // set latest fum price
        _setLatestFumPrice(fumPrice());
        return usmMinted;
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     *
     * @param _usmToBurn Amount of USM to burn.
     * @return ETH sent
     */
    function burn(uint _usmToBurn) external returns (uint) {
        require(_usmToBurn >= MIN_BURN_AMOUNT, "Must burn at least 1 USM");
        uint ethToSend = _burn(_usmToBurn);
        require(debtRatio() <= MAX_DEBT_RATIO,
            "Cannot burn this amount. Will take debt ratio above maximum.");
        Address.sendValue(msg.sender, ethToSend);
        // set latest fum price
        _setLatestFumPrice(fumPrice());
        return (ethToSend);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     */
    function fund() external payable {
        require(msg.value > MIN_ETH_AMOUNT, "Must deposit more than 0.001 ETH");
        if(debtRatio() > MAX_DEBT_RATIO){
            uint ethNeeded = _usmToEth(totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(ethPool).add(1); //+ 1 to tip it over the edge
            if (msg.value >= ethNeeded) { // Split into two fundings at different prices
                _fund(msg.sender, ethNeeded);
                _fund(msg.sender, msg.value.sub(ethNeeded));
                return;
            } // Otherwise continue for funding the total at a single price
        }
        _fund(msg.sender, msg.value);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function _fund(address to, uint ethIn) internal {
        uint fumPrice = fumPrice();
        uint fumOut = fumPrice.wadMul(ethIn);
        ethPool = ethPool.add(ethIn);
        fum.mint(to, fumOut);
        _setLatestFumPrice(fumPrice);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH
     * from the pool
     */
    function defund(uint _fumAmount) external {
        require(_fumAmount >= WAD, "Must defund at least 1 FUM");
        uint fumPrice = fumPrice();
        uint ethAmount = _fumAmount.wadDiv(fumPrice);
        ethPool = ethPool.sub(ethAmount);
        require(totalSupply().wadDiv(_ethToUsm(ethPool)) <= MAX_DEBT_RATIO,
            "Cannot defund this amount. Will take debt ratio above maximum.");
        fum.burn(msg.sender, _fumAmount);
        Address.sendValue(msg.sender, ethAmount);
        // set latest fum price
        _setLatestFumPrice(fumPrice);
    }

    /**
     * @notice Set the latest fum price. Emits a LatestFumPriceChanged event.
     *
     * @param _fumPrice the latest fum price
     */
    function _setLatestFumPrice(uint _fumPrice) internal {
        uint previous = latestFumPrice;
        latestFumPrice = _fumPrice;
        emit LatestFumPriceChanged(previous, latestFumPrice);
    }
}