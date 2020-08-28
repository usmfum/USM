pragma solidity ^0.6.7;

import "./BufferedToken.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./WadMath.sol";
import "@nomiclabs/buidler/console.sol";
import "./FUM.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff)
 */
contract USM is BufferedToken {
    using SafeMath for uint;
    using WadMath for uint;

    uint constant MINT_FEE = WAD / 1000; // 0.1%
    uint constant BURN_FEE = WAD / 200; // 0.5%
    uint constant MAX_DEBT_RATIO = 900000000000000000; // 90%

    address fum;
    uint public latestFumPrice;

    event LatestFumPriceChanged(uint previous, uint latest);

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public BufferedToken(_oracle, "Minimal USD", "USM") {
        _setLatestFumPrice(MINT_FEE);
        fum = address(new FUM());
    }

    /**
     * @notice Mint ETH for USM. Uses msg.value as the ETH deposit.
     */
    function mint() external payable {
        require(msg.value > MINT_FEE, "Must deposit more than 0.001 ETH");
        uint usmAmount = _ethToUsm(msg.value);
        uint usmMinusFee = usmAmount.sub(usmAmount.wadMul(MINT_FEE));
        ethPool = ethPool.add(msg.value);
        _mint(msg.sender, usmMinusFee);
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
        uint ethMinusFee = ethAmount.sub(ethAmount.wadMul(BURN_FEE));
        ethPool = ethPool.sub(ethMinusFee);
        require(totalSupply().sub(_usmAmount).wadDiv(_ethToUsm(ethPool)) <= MAX_DEBT_RATIO,
            "Cannot burn this amount. Will take debt ratio above maximum.");
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethMinusFee);
        // set latest fum price
        _setLatestFumPrice(fumPrice());
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function fund() external payable {
        require(msg.value > MINT_FEE, "Must deposit more than 0.001 ETH");
        if(debtRatio() > MAX_DEBT_RATIO){
            uint ethNeeded = _usmToEth(totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(ethPool).add(1); //+ 1 to tip it over the edge
            // If the eth sent isn't enough to dip below MAX_DEBT_RATIO, then don't do this.
            // Skip straight to minting at the current price
            if (msg.value > ethNeeded) {
                // calculate amount of FUM to mint whilst above the max
                uint aboveMaxFum = ethNeeded.wadMul(fumPrice());
                // calculate amount to mint at price below the max
                // this will increase the buffer
                ethPool = ethPool.add(ethNeeded);
                uint ethLeft = ethNeeded.sub(msg.value);
                // get the new fum price now that the buffer has increased
                uint newFumPrice = fumPrice();
                uint belowMaxFum = ethLeft.wadMul(newFumPrice);
                ethPool = ethPool.add(ethLeft);
                // mint
                FUM(fum).mint(msg.sender, aboveMaxFum.add(belowMaxFum));
                //set latest fum price
                _setLatestFumPrice(newFumPrice);
                return;
            }
        }
        uint fumPrice = fumPrice();
        uint fumAmount = fumPrice.wadMul(msg.value);
        ethPool = ethPool.add(msg.value);
        FUM(fum).mint(msg.sender, fumAmount);
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
        uint ethMinusFee = ethAmount.sub(ethAmount.wadMul(BURN_FEE));
        ethPool = ethPool.sub(ethMinusFee);
        require(totalSupply().wadDiv(_ethToUsm(ethPool)) <= MAX_DEBT_RATIO,
            "Cannot defund this amount. Will take debt ratio above maximum.");
        FUM(fum).burn(msg.sender, _fumAmount);
        Address.sendValue(msg.sender, ethMinusFee);
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

        uint fumTotalSupply = FUM(fum).totalSupply();
        // If there are no FUM, assume there's 1
        if (fumTotalSupply == 0) {
            fumTotalSupply = WAD;
        }
        return uint(buffer).wadDiv(fumTotalSupply);
    }
}