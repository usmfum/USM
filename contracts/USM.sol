// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./BufferedToken.sol";
import "./DecimalMath.sol";
import "./USMMath.sol";
import "./FUM.sol";
import "@nomiclabs/buidler/console.sol";


/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is BufferedToken, USMMath {
    using DecimalMath for DecimalMath.UFixed;
    using DecimalMath for uint;
    using SafeMath for uint;

    uint constant MIN_ETH_AMOUNT = 1e15;            // 0.001 (of an ETH)
    DecimalMath.UFixed public MAX_DEBT_RATIO = DecimalMath.UFixed({ value: DecimalMath.UNIT * 9/10 }); // 90%

    FUM public fum;
    DecimalMath.UFixed public latestFumPrice;

    event LatestFumPriceChanged(uint previous, uint latest);

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public BufferedToken(_oracle, "Minimal USD", "USM") {
        _setLatestFumPrice(MIN_ETH_AMOUNT.toUFixed());
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
        require(totalSupply().sub(_usmAmount).divd(_ethToUsm(ethPool)).leq(MAX_DEBT_RATIO),
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
        if(debtRatio().gt(MAX_DEBT_RATIO)){
            uint ethNeeded = _usmToEth(totalSupply()).divd(MAX_DEBT_RATIO).sub(ethPool).add(1); //+ 1 to tip it over the edge
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
        DecimalMath.UFixed memory fumPrice = fumPrice();
        uint fumOut = ethIn.muld(fumPrice);
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
        DecimalMath.UFixed memory fumPrice = fumPrice();
        uint ethAmount = _fumAmount.divd(fumPrice);
        ethPool = ethPool.sub(ethAmount);
        require(totalSupply().divd(_ethToUsm(ethPool)).leq(MAX_DEBT_RATIO),
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
    function _setLatestFumPrice(DecimalMath.UFixed memory _fumPrice) internal {
        DecimalMath.UFixed memory previous = latestFumPrice;
        latestFumPrice = _fumPrice;
        emit LatestFumPriceChanged(previous.value, latestFumPrice.value);
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and ETH buffer
     */
    function fumPrice() public view returns (DecimalMath.UFixed memory) {
        int buffer = ethBuffer();
        // if we're underwater, use the last fum price
        if (buffer <= 0 || debtRatio().gt(MAX_DEBT_RATIO)) {
            return latestFumPrice;
        }

        uint fumTotalSupply = fum.totalSupply();
        // If there are no FUM, assume there's 1
        if (fumTotalSupply == 0) {
            fumTotalSupply = WAD;
        }
        return uint(buffer).divd(fumTotalSupply);
    }
}