pragma solidity ^0.6.7;

import "@openzeppelin/contracts/math/SafeMath.sol";
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
    using WadMath for uint;

    uint constant MIN_ETH_AMOUNT = WAD / 1000;         // 0.001 (of an ETH)
    uint constant MAX_DEBT_RATIO = 900000000000000000; // 90%

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
     * @notice Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        require(msg.value > MIN_ETH_AMOUNT, "Must deposit more than 0.001 ETH");
        uint usmAmount = _ethToUsm(msg.value);
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmAmount);
        // set latest fum price
        _setLatestFumPrice(fumPrice());
    }

    /**
     * @notice Burn USM for ETH.
     *
     * @param _usmAmount Amount of USM to burn.
     */
    function burn(uint _usmAmount) external {
        require(_usmAmount >= WAD, "Must burn at least 1 USM");
        uint ethAmount = _usmToEth(_usmAmount);
        ethPool = ethPool.sub(ethAmount);
        require(totalSupply().sub(_usmAmount).wadDiv(_ethToUsm(ethPool)) <= MAX_DEBT_RATIO,
            "Cannot burn this amount. Will take debt ratio above maximum.");
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethAmount);
        // set latest fum price
        _setLatestFumPrice(fumPrice());
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

        uint fumTotalSupply = fum.totalSupply();
        // If there are no FUM, assume there's 1
        if (fumTotalSupply == 0) {
            fumTotalSupply = WAD;
        }
        return uint(buffer).wadDiv(fumTotalSupply);
    }
}