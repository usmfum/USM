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
    uint public minFumBuyPrice;

    event MinFumBuyPriceChanged(uint debtRatio, uint priceBefore, uint priceAfter);

    /**
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) public BufferedToken(_oracle, "Minimal USD", "USM") {
        minFumBuyPrice = 0;
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
        _checkDebtRatio();
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
        _burn(msg.sender, _usmAmount);
        Address.sendValue(msg.sender, ethMinusFee);
        _checkDebtRatio();
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function fund() external payable {
        require(msg.value > MINT_FEE, "Must deposit more than 0.001 ETH");
        uint fumAmount = fumPrice().wadMul(msg.value);
        ethPool = ethPool.add(msg.value);
        FUM(fum).mint(msg.sender, fumAmount);
        _checkDebtRatio();
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH
     * from the pool
     */
    function defund(uint _fumAmount) external {
        require(_fumAmount >= WAD, "Must defund at least 1 FUM");
        uint ethAmount = _fumAmount.wadDiv(fumPrice());
        uint ethMinusFee = ethAmount.sub(ethAmount.wadMul(BURN_FEE));
        ethPool = ethPool.sub(ethMinusFee);
        FUM(fum).burn(msg.sender, _fumAmount);
        Address.sendValue(msg.sender, ethMinusFee);
        _checkDebtRatio();
    }
    
    /**
     * @notice Get the fum price whether under or over the debt ratio
     *
     * @return _fumPrice The price of FUM
     */
    function fumPrice() public returns (uint) {
        uint price = WAD;
        if (debtRatio() >= MAX_DEBT_RATIO) {
            if (minFumBuyPrice == 0) {
                _checkDebtRatio();
            }
            price = minFumBuyPrice;
        }
        else{
            price = _fumPrice(uint(ethBuffer()));
        }
        return price;
    }

    /**
     * @notice Checks the debt ratio and sets the minFumBuyPrice
     * if the ratio has crossed the MAX threshold in either direction
     */
    function _checkDebtRatio() internal {
        uint previousMinFumBuyPrice = minFumBuyPrice;
        // If the debtRatio has just risen above the MAX
        if (debtRatio() >= MAX_DEBT_RATIO && minFumBuyPrice == 0) {
            int buffer = ethBuffer();
            if (buffer <= 0) {
                // TODO fix this - cuurently sets price to 0.001 ETH
                minFumBuyPrice = MINT_FEE;
            }
            else{
                minFumBuyPrice = _fumPrice(uint(buffer));
            }
            emit MinFumBuyPriceChanged(debtRatio(), previousMinFumBuyPrice, minFumBuyPrice);
        }
        // If the debtRatio has just dropped below the MAX
        else if (debtRatio() < MAX_DEBT_RATIO && minFumBuyPrice != 0) {
            minFumBuyPrice = 0;
            emit MinFumBuyPriceChanged(debtRatio(), previousMinFumBuyPrice, minFumBuyPrice);
        }
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and a specified ETH buffer
     */
    function _fumPrice(uint _buffer) internal view returns (uint) {
        uint fumTotalSupply = FUM(fum).totalSupply();
        if (fumTotalSupply == 0) {
            fumTotalSupply = WAD;
        }
        return uint(_buffer).wadDiv(fumTotalSupply);
    }
}