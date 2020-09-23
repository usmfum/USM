// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "delegable.sol/contracts/Delegable.sol";
import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "./oracles/IOracle.sol";
// import "@nomiclabs/buidler/console.sol";

/**
 * @title USM Stable Coin
 * @author Alex Roan (@alexroan)
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is IUSM, ERC20Permit, Delegable {
    using SafeMath for uint;
    using WadMath for uint;

    address public oracle;
    IERC20 public eth;
    FUM public fum;
    uint public minFumBuyPrice;                               // in units of ETH. default 0

    uint public constant WAD = 10 ** 18;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;       // 80%

    /**
     * @param oracle_ Address of the oracle
     */
    constructor(address oracle_, address eth_) public ERC20Permit("Minimal USD", "USM") {
        fum = new FUM();
        oracle = oracle_;
        eth = IERC20(eth_);
    }

    /** EXTERNAL FUNCTIONS **/

    /**
     * @notice Mint ETH for USM with checks and asset transfers. Uses msg.value as the ETH deposit.
     * @param ethIn Amount of wrapped Ether to use for minting USM.
     * @return USM minted
     */
    function mint(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint)
    {
        require(eth.transferFrom(from, address(this), ethIn), "Eth transfer fail");
        require(fum.totalSupply() > 0, "Fund before minting");
        uint usmMinted = ethToUsm(ethIn);
        _mint(to, usmMinted);
        return usmMinted;
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     *
     * @param usmToBurn Amount of USM to burn.
     * @return ETH sent
     */
    function burn(address from, address to, uint usmToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint)
    {
        uint ethOut = usmToEth(usmToBurn);
        _burn(from, usmToBurn);
        require(eth.transfer(to, ethOut), "Eth transfer fail");
        require(debtRatio() <= WAD, "Debt ratio too high");
        return (ethOut);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     * @param ethIn Amount of wrapped Ether to use for minting FUM.
     */
    function fund(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint)
    {
        require(eth.transferFrom(from, address(this), ethIn), "Eth transfer fail");
        if(debtRatio() > MAX_DEBT_RATIO){
            // calculate the ETH needed to bring debt ratio to suitable levels
            uint ethNeeded = usmToEth(totalSupply()).wadDiv(MAX_DEBT_RATIO).sub(ethPool()).add(1); //+ 1 to tip it over the edge
            if (ethIn >= ethNeeded) { // Split into two fundings at different prices, and return the combined produced fum
                return _fund(to, ethIn.sub(ethNeeded)).add(_fund(to, ethNeeded));
            } // Otherwise continue for funding the total at a single price
        }
        return _fund(to, ethIn);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH from the pool
     * @param fumToBurn Amount of FUM to burn.
     */
    function defund(address from, address to, uint fumToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint)
    {
        uint ethOut = fumToBurn.wadMul(fumPrice(Side.Sell));
        fum.burn(from, fumToBurn);
        require(eth.transfer(to, ethOut), "Eth transfer fail");
        require(debtRatio() <= MAX_DEBT_RATIO, "Max debt ratio breach");
        return (ethOut);
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract)
     *
     * @return ETH pool
     */
    function ethPool() public override view returns (uint) {
        return eth.balanceOf(address(this));
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public override view returns (int) {
        uint pool = ethPool();
        int buffer = int(pool) - int(usmToEth(totalSupply()));
        require(buffer <= int(pool), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio of the current Eth pool amount and outstanding USM
     * (the amount of USM in total supply).
     *
     * @return Debt ratio.
     */
    function debtRatio() public override view returns (uint) {
        uint pool = ethPool();
        if (pool == 0) {
            return 0;
        }
        return totalSupply().wadDiv(ethToUsm(pool));
    }

    /**
     * @notice Calculates the price of FUM using its total supply
     * and ETH buffer
     */
    function fumPrice(Side side) public override view returns (uint) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToEth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        uint theoreticalFumPrice = uint(ethBuffer()).wadDiv(fumTotalSupply);
        // if side == buy, floor the price at minFumBuyPrice
        if ((side == Side.Buy) && (minFumBuyPrice > theoreticalFumPrice)) {
            return minFumBuyPrice;
        }
        return theoreticalFumPrice;
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function ethToUsm(uint ethAmount) public override view returns (uint) {
        return _oraclePrice().wadMul(ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function usmToEth(uint usmAmount) public override view returns (uint) {
        return usmAmount.wadDiv(_oraclePrice());
    }

    /** INTERNAL FUNCTIONS */

    /**
     * @notice Set the min fum price, based on the current oracle price and debt ratio. Emits a MinFumBuyPriceChanged event.
     * @dev The logic for calculating a new minFumBuyPrice is as follows.  We want to set it to the FUM price, in ETH terms, at
     * which debt ratio was exactly MAX_DEBT_RATIO.  So we can assume:
     *
     *     usmToEth(totalSupply()) / ethPool() = MAX_DEBT_RATIO, or in other words:
     *     usmToEth(totalSupply()) = MAX_DEBT_RATIO * ethPool()
     *
     * And with this assumption, we calculate the FUM price (buffer / FUM qty) like so:
     *
     *     minFumBuyPrice = ethBuffer() / fum.totalSupply()
     *                    = (ethPool() - usmToEth(totalSupply())) / fum.totalSupply()
     *                    = (ethPool() - (MAX_DEBT_RATIO * ethPool())) / fum.totalSupply()
     *                    = (1 - MAX_DEBT_RATIO) * ethPool() / fum.totalSupply()
     */
    function _updateMinFumBuyPrice() internal {
        uint previous = minFumBuyPrice;
        if (debtRatio() <= MAX_DEBT_RATIO) {                // We've dropped below (or were already below, whatev) max debt ratio
            minFumBuyPrice = 0;                             // Clear mfbp
        } else if (minFumBuyPrice == 0) {                   // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            minFumBuyPrice = (WAD - MAX_DEBT_RATIO).wadMul(ethPool()).wadDiv(fum.totalSupply());
        }

        emit MinFumBuyPriceChanged(previous, minFumBuyPrice);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price
     */
    function _fund(address to, uint ethIn) internal returns (uint) {
        _updateMinFumBuyPrice();
        uint fumOut = ethIn.wadDiv(fumPrice(Side.Buy));
        fum.mint(to, fumOut);
        return fumOut;
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