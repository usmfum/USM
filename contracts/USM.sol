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

    IOracle public oracle;
    ERC20 public weth;
    FUM public fum;
    uint public latestFumPrice;                               // default 0

    uint public constant WAD = 10 ** 18;
    uint constant public MIN_WETH_AMOUNT = WAD / 1000;         // 0.001 WETH
    uint constant public MIN_BURN_AMOUNT = WAD;               // 1 USM
    uint constant public MAX_DEBT_RATIO = WAD * 8 / 10;       // 80%

    event LatestFumPriceChanged(uint previous, uint latest);

    /**
     * @param oracle_ Address of the oracle
     */
    constructor(address oracle_, address weth_) public ERC20("Minimal USD", "USM") {
        fum = new FUM();
        oracle = IOracle(oracle_);
        weth = ERC20(weth_);
        _setLatestFumPrice();
    }

    /** EXTERNAL FUNCTIONS **/

    /**
     * @notice Mint WETH for USM with checks and asset transfers.
     * @param wethAmount Weth to take for minting USM
     * @return USM minted
     */
    function mint(uint wethAmount) external returns (uint) {
        require(wethAmount > MIN_WETH_AMOUNT, "0.001 WETH minimum");
        require(weth.transferFrom(msg.sender, address(this), wethAmount), "Weth transfer fail");
        require(fum.totalSupply() > 0, "Fund before minting");

        uint usmMinted = wethToUsm(wethAmount);
        _mint(msg.sender, usmMinted);
        // set latest fum price
        _setLatestFumPrice();
        return usmMinted;
    }

    /**
     * @notice Burn USM for WETH with checks and asset transfers.
     *
     * @param usmToBurn Amount of USM to burn.
     * @return WETH sent
     */
    function burn(uint usmToBurn) external returns (uint) {
        require(usmToBurn >= MIN_BURN_AMOUNT, "1 USM minimum"); // TODO: Needed?

        uint wethToSend = usmToWeth(usmToBurn);
        _burn(msg.sender, usmToBurn);
        weth.transfer(msg.sender, wethToSend);
        // set latest fum price
        _setLatestFumPrice();

        require(debtRatio() <= WAD, "Debt ratio too high");
        return (wethToSend);
    }

    /**
     * @notice Funds the pool with WETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     * @param wethAmount Weth to take for minting FUM
     */
    function fund(uint wethAmount) external returns (uint) {
        require(wethAmount > MIN_WETH_AMOUNT, "0.001 WETH minimum"); // TODO: Needed?
        require(weth.transferFrom(msg.sender, address(this), wethAmount), "Weth transfer fail");
        
        if(debtRatio() > MAX_DEBT_RATIO){
            // calculate the WETH needed to bring debt ratio to suitable levels
            uint wethNeeded = usmToWeth(
                totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(weth.balanceOf(address(this))
            ).add(1); //+ 1 to tip it over the edge
            if (wethAmount >= wethNeeded) { // Split into two fundings at different prices
                uint fumAmount;
                fumAmount = fumAmount.add(_fund(msg.sender, wethNeeded));
                fumAmount = fumAmount.add(_fund(msg.sender, wethAmount.sub(wethNeeded)));
                return fumAmount;
            } // Otherwise continue for funding the total at a single price
        }
        return _fund(msg.sender, wethAmount);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent WETH from the pool
     * @param fumAmount FUM to burn in exchange for Weth
     */
    function defund(uint fumAmount) external returns (uint){
        require(fumAmount >= MIN_BURN_AMOUNT, "1 FUM minimum"); // TODO: Needed?

        uint wethAmount = fumAmount.wadMul(fumPrice());
        fum.burn(msg.sender, fumAmount);
        weth.transfer(msg.sender, wethAmount);
        // set latest fum price
        _setLatestFumPrice();

        require(debtRatio() <= MAX_DEBT_RATIO, "Max debt ratio breach");
        return wethAmount;
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Calculate the amount of WETH in the buffer
     *
     * @return WETH buffer
     */
    function wethBuffer() public view returns (int) {
        int balance = int(weth.balanceOf(address(this))); // TODO: SafeCast 
        int buffer = balance - int(usmToWeth(totalSupply()));
        require(buffer <= balance, "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Weth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        if (weth.balanceOf(address(this)) == 0) {
            return 0;
        }
        return totalSupply().wadDiv(wethToUsm(weth.balanceOf(address(this))));
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and WETH buffer
     */
    function fumPrice() public view returns (uint) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToWeth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in WETH terms)
        }
        int buffer = wethBuffer();
        // if we're underwater, use the last fum price
        if (buffer <= 0 || debtRatio() > MAX_DEBT_RATIO) {
            return latestFumPrice;
        }
        return uint(buffer).wadDiv(fumTotalSupply);
    }

    /**
     * @notice Convert WETH amount to USM using the latest price of USM
     * in WETH.
     *
     * @param wethAmount The amount of WETH to convert.
     * @return The amount of USM.
     */
    function wethToUsm(uint wethAmount) public view returns (uint) {
        return _oraclePrice().wadMul(wethAmount);
    }

    /**
     * @notice Convert USM amount to WETH using the latest price of USM
     * in WETH.
     *
     * @param usmAmount The amount of USM to convert.
     * @return The amount of WETH.
     */
    function usmToWeth(uint usmAmount) public view returns (uint) {
        return usmAmount.wadDiv(_oraclePrice());
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
     * @notice Funds the pool with WETH, minting FUM at its current price
     */
    function _fund(address to, uint wethIn) internal returns (uint) {
        uint _fumPrice = fumPrice();
        uint fumOut = wethIn.wadDiv(_fumPrice);
        fum.mint(to, fumOut);
        _setLatestFumPrice();
        return fumOut;
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(oracle.decimalShift(), UNIT) function.
        return oracle.latestPrice().mul(WAD).div(10 ** oracle.decimalShift());
    }
}