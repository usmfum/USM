// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./Delegable.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "./oracles/Oracle.sol";
// import "@nomiclabs/buidler/console.sol";

/**
 * @title USMTemplate
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 *
 * This abstract USM contract must be inherited by a concrete implementation, that also adds an Oracle implementation - eg, by 
 * also inheriting a concrete Oracle implementation.  See USM (and MockUSM) for an example.
 *
 * We use this inheritance-based design (rather than the more natural, and frankly normally more correct, composition-based design
 * of storing the Oracle here as a variable), because inheriting the Oracle makes all the latestPrice() calls *internal* rather
 * than calls to a separate oracle contract (or multiple contracts) - which leads to a significant saving in gas.
 */
abstract contract USMTemplate is IUSM, Oracle, ERC20Permit, Delegable {
    using SafeMath for uint;
    using WadMath for uint;

    enum Side {Buy, Sell}

    event MinFumBuyPriceChanged(uint previous, uint latest);
    event BuySellAdjustmentChanged(uint previous, uint latest);

    uint public constant WAD = 10 ** 18;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                 // 80%
    uint public constant MIN_FUM_BUY_PRICE_HALF_LIFE = 1 days;          // Solidity for 1 * 24 * 60 * 60
    uint public constant BUY_SELL_ADJUSTMENT_HALF_LIFE = 1 minutes;     // Solidity for 1 * 60

    IERC20 public eth;
    FUM public fum;

    struct TimedValue {
        uint32 timestamp;
        uint224 value;
    }

    TimedValue public minFumBuyPriceStored;
    TimedValue public buySellAdjustmentStored = TimedValue({ timestamp: 0, value: uint224(WAD) });

    constructor(address eth_) public ERC20Permit("Minimal USD", "USM")
    {
        eth = IERC20(eth_);
        fum = new FUM(address(this));
    }

    /** EXTERNAL TRANSACTIONAL FUNCTIONS **/

    /**
     * @notice Mint ETH for USM with checks and asset transfers.  Uses msg.value as the ETH deposit.
     * FUM needs to be funded before USM can be minted.
     * @param ethIn Amount of wrapped Ether to use for minting USM
     * @return usmOut USM minted
     */
    function mint(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint usmOut)
    {
        // First check that fund() has been called first - no minting before funding:
        uint ethInPool = ethPool();
        require(ethInPool > 0, "Fund before minting");

        // Then calculate:
        uint ethUsmPrice = latestPrice();
        uint usmTotalSupply = totalSupply();
        uint oldDebtRatio = debtRatio(ethUsmPrice, ethInPool, usmTotalSupply);
        usmOut = usmFromMint(ethUsmPrice, ethIn, ethInPool, usmTotalSupply, oldDebtRatio);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        _mint(to, usmOut);
        uint newDebtRatio = debtRatio(ethUsmPrice, ethInPool.add(ethIn), usmTotalSupply.add(usmOut));
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio, newDebtRatio, buySellAdjustment());
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     * @param usmToBurn Amount of USM to burn
     * @return ethOut ETH sent
     */
    function burn(address from, address to, uint usmToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        // First calculate:
        uint ethUsmPrice = latestPrice();
        uint ethInPool = ethPool();
        uint usmTotalSupply = totalSupply();
        uint oldDebtRatio = debtRatio(ethUsmPrice, ethInPool, usmTotalSupply);
        ethOut = ethFromBurn(ethUsmPrice, usmToBurn, ethInPool, usmTotalSupply, oldDebtRatio);

        // Then update state:
        _burn(from, usmToBurn);
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        uint newDebtRatio = debtRatio(ethUsmPrice, ethInPool.sub(ethOut), usmTotalSupply.sub(usmToBurn));
        require(newDebtRatio <= WAD, "Debt ratio too high");
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio, newDebtRatio, buySellAdjustment());
    }

    /**
     * @notice Fund the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over.
     * @param ethIn Amount of wrapped Ether to use for minting FUM
     * @return fumOut FUM sent
     */
    function fund(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint fumOut)
    {
        // First refresh mfbp:
        uint ethUsmPrice = latestPrice();
        uint ethInPool = ethPool();
        uint usmTotalSupply = totalSupply();
        uint oldDebtRatio = debtRatio(ethUsmPrice, ethInPool, usmTotalSupply);
        uint fumTotalSupply = fum.totalSupply();
        _updateMinFumBuyPrice(oldDebtRatio, ethInPool, fumTotalSupply);

        // Then calculate:
        uint adjustment = buySellAdjustment();
        fumOut = fumFromFund(ethUsmPrice, ethIn, ethInPool, usmTotalSupply, oldDebtRatio, fumTotalSupply, adjustment);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        fum.mint(to, fumOut);
        uint newDebtRatio = debtRatio(ethUsmPrice, ethInPool.add(ethIn), usmTotalSupply);
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio, newDebtRatio, adjustment);
    }

    /**
     * @notice Defund the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param fumToBurn Amount of FUM to burn
     * @return ethOut ETH sent
     */
    function defund(address from, address to, uint fumToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        // First calculate:
        uint ethUsmPrice = latestPrice();
        uint ethInPool = ethPool();
        uint usmTotalSupply = totalSupply();
        uint oldDebtRatio = debtRatio(ethUsmPrice, ethInPool, usmTotalSupply);
        ethOut = ethFromDefund(ethUsmPrice, fumToBurn, ethInPool, usmTotalSupply, oldDebtRatio);

        // Then update state:
        fum.burn(from, fumToBurn);
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        uint newDebtRatio = debtRatio(ethUsmPrice, ethInPool.sub(ethOut), usmTotalSupply);
        require(newDebtRatio <= MAX_DEBT_RATIO, "Max debt ratio breach");
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio, newDebtRatio, buySellAdjustment());
    }

    /**
     * @notice Regular transfer, disallowing transfers to this contract.
     * @return success Transfer successfumPrice
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool success) {
        require(recipient != address(this) && recipient != address(fum), "Don't transfer here");
        _transfer(_msgSender(), recipient, amount);
        success = true;
    }

    /** INTERNAL TRANSACTIONAL FUNCTIONS */

    /**
     * @notice Set the min FUM price, based on the current oracle price and debt ratio. Emits a MinFumBuyPriceChanged event.
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
    function _updateMinFumBuyPrice(uint debtRatio_, uint ethInPool, uint fumTotalSupply) internal {
        uint previous = minFumBuyPriceStored.value;
        if (debtRatio_ <= MAX_DEBT_RATIO) {                 // We've dropped below (or were already below, whatev) max debt ratio
            if (previous != 0) {
                minFumBuyPriceStored.timestamp = 0;         // Clear mfbp
                minFumBuyPriceStored.value = 0;
                emit MinFumBuyPriceChanged(previous, 0);
            }
        } else if (previous == 0) {                         // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            minFumBuyPriceStored.timestamp = uint32(block.timestamp);
            minFumBuyPriceStored.value = uint224((WAD - MAX_DEBT_RATIO).mul(ethInPool).div(fumTotalSupply));
            emit MinFumBuyPriceChanged(previous, minFumBuyPriceStored.value);
        }
    }

    /**
     * @notice Update the buy/sell adjustment factor, as of the current block time, after a price-moving operation.
     * @param oldDebtRatio The debt ratio before the operation (eg, mint()) was done
     * @param newDebtRatio The current, post-op debt ratio
     */
    function _updateBuySellAdjustmentIfNeeded(uint oldDebtRatio, uint newDebtRatio, uint oldAdjustment) internal {
        if (oldDebtRatio != 0 && newDebtRatio != 0) {
            uint previous = buySellAdjustmentStored.value;
            // Eg: if a user operation reduced debt ratio from 70% to 50%, it was either a fund() or a burn().  These are both
            // "long-ETH" operations.  So we can take old / new = 70% / 50% = 1.4 as the ratio by which to increase
            // buySellAdjustment, which is intended as a measure of "how long-ETH recent user activity has been":
            uint newAdjustment = oldAdjustment.mul(oldDebtRatio).div(newDebtRatio);
            buySellAdjustmentStored.timestamp = uint32(block.timestamp);
            buySellAdjustmentStored.value = uint224(newAdjustment);
            emit BuySellAdjustmentChanged(previous, newAdjustment);
        }
    }

    /** PUBLIC AND INTERNAL VIEW FUNCTIONS **/

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return pool ETH pool
     */
    function ethPool() public view returns (uint pool) {
        pool = eth.balanceOf(address(this));
    }

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(uint ethUsmPrice, uint ethInPool, uint usmTotalSupply) internal pure returns (int buffer) {
        buffer = int(ethInPool) - int(usmToEth(ethUsmPrice, usmTotalSupply));
        require(buffer <= int(ethInPool), "Underflow error");
    }

    /**
     * @notice Calculate debt ratio for a given eth to USM price: ratio of the outstanding USM (amount of USM in total supply), to
     * the current ETH pool amount.
     * @return ratio Debt ratio
     */
    function debtRatio(uint ethUsmPrice, uint ethInPool, uint usmTotalSupply) internal pure returns (uint ratio) {
        uint usmOut = ethUsmPrice.wadMul(ethInPool);
        ratio = (ethInPool == 0 ? 0 : usmTotalSupply.wadDiv(usmOut));
    }

    /**
     * @notice Convert ETH amount to USM using a ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethUsmPrice, uint ethAmount) internal pure returns (uint usmOut) {
        usmOut = ethAmount.wadMul(ethUsmPrice);
    }

    /**
     * @notice Convert USM amount to ETH using a ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint ethUsmPrice, uint usmAmount) internal pure returns (uint ethOut) {
        ethOut = usmAmount.wadDiv(ethUsmPrice);
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(Side side, uint ethUsmPrice) internal view returns (uint price) {
        price = usmToEth(ethUsmPrice, WAD);

        uint adjustment = buySellAdjustment();
        if ((side == Side.Buy && adjustment < WAD) || (side == Side.Sell && adjustment > WAD)) {
            price = price.wadDiv(adjustment);
        }
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price FUM price in ETH terms
     */
    function fumPrice(Side side, uint ethUsmPrice, uint ethInPool, uint usmTotalSupply, uint fumTotalSupply, uint adjustment)
        internal view returns (uint price)
    {
        if (fumTotalSupply == 0) {
            return usmToEth(ethUsmPrice, WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        int buffer = ethBuffer(ethUsmPrice, ethInPool, usmTotalSupply);
        price = (buffer < 0 ? 0 : uint(buffer).wadDiv(fumTotalSupply));

        if (side == Side.Buy) {
            if (adjustment > WAD) {
                price = price.wadMul(adjustment);
            }
            // Floor the buy price at minFumBuyPrice:
            uint mfbp = minFumBuyPrice();
            if (price < mfbp) {
                price = mfbp;
            }
        } else {
            if (adjustment < WAD) {
                price = price.wadMul(adjustment);
            }
        }
    }

    /**
     * @notice How much USM a minter currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     * @param ethIn The amount of ETH passed to mint()
     * @return usmOut The amount of USM to receive in exchange
     */
    function usmFromMint(uint ethUsmPrice, uint ethIn, uint ethQty0, uint usmQty0, uint debtRatio0)
        internal view returns (uint usmOut)
    {
        // Mint USM at a sliding-up USM price (ie, at a sliding-down ETH price).  **BASIC RULE:** anytime debtRatio() changes by
        // factor k (here > 1), ETH price changes by factor 1/k (ie, USM price, in ETH terms, changes by factor k).  (Earlier
        // versions of this logic scaled ETH price based on the change in ethPool(), or change in ethPool() squared: the latter
        // gives simpler math - no sqrt() - but doesn't let mint/burn offset fund/defund, which using debtRatio() nicely does.)
        uint usmPrice0 = usmPrice(Side.Buy, ethUsmPrice);
        if (debtRatio0 == 0) {
            // No USM in the system, so debtRatio() == 0 which breaks the integral below - skip sliding-prices this time:
            usmOut = ethIn.wadDiv(usmPrice0);
        } else {
            uint ethQty1 = ethQty0.add(ethIn);

            // Math: this is an integral - sum of all USM minted at a sliding-down ETH price:
            uint integralFirstPart = debtRatio0.wadMul(ethQty1.wadSquared().sub(ethQty0.wadSquared()));
            uint usmQty1 = integralFirstPart.add(usmQty0.wadMul(usmPrice0).wadSquared()).wadSqrt().wadDiv(usmPrice0);
            usmOut = usmQty1.sub(usmQty0);
        }
    }

    /**
     * @notice How much ETH a burner currently gets from burning usmIn USM, accounting for adjustment and sliding prices.
     * @param usmIn The amount of USM passed to burn()
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromBurn(uint ethUsmPrice, uint usmIn, uint ethQty0, uint usmQty0, uint debtRatio0)
        internal view returns (uint ethOut)
    {
        // Burn USM at a sliding-down USM price (ie, a sliding-up ETH price):
        uint usmPrice0 = usmPrice(Side.Sell, ethUsmPrice);
        uint usmQty1 = usmQty0.sub(usmIn);

        // Math: this is an integral - sum of all USM burned at a sliding price.  Follows the same mathematical invariant as
        // above: if debtRatio() *= k (here, k < 1), ETH price *= 1/k, ie, USM price in ETH terms *= k.
        uint integralFirstPart = usmQty0.wadSquared().sub(usmQty1.wadSquared()).wadMul(usmPrice0.wadSquared());
        uint ethQty1 = ethQty0.wadSquared().sub(integralFirstPart.wadDiv(debtRatio0)).wadSqrt();
        ethOut = ethQty0.sub(ethQty1);
    }

    /**
     * @notice How much FUM a funder currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     * @param ethIn The amount of ETH passed to fund()
     * @return fumOut The amount of FUM to receive in exchange
     */
    function fumFromFund(uint ethUsmPrice, uint ethIn, uint ethQty0, uint usmQty0, uint debtRatio0, uint fumQty0, uint adjustment)
        internal view returns (uint fumOut)
    {
        // Create FUM at a sliding-up FUM price:
        uint fumPrice0 = fumPrice(Side.Buy, ethUsmPrice, ethQty0, usmQty0, fumQty0, adjustment);
        if (debtRatio0 == 0) {
            // No USM in the system - skip sliding-prices:
            fumOut = ethIn.wadDiv(fumPrice0);
        } else {
            uint ethQty1 = ethQty0.add(ethIn);

            // Math: see closely analogous comment in usmFromMint() above.
            uint integralFirstPart = debtRatio0.wadMul(ethQty1.wadSquared().sub(ethQty0.wadSquared()));
            uint fumQty1 = integralFirstPart.add(fumQty0.wadMul(fumPrice0).wadSquared()).wadSqrt().wadDiv(fumPrice0);
            fumOut = fumQty1.sub(fumQty0);
        }
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustment and sliding prices.
     * @param fumIn The amount of FUM passed to defund()
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromDefund(uint ethUsmPrice, uint fumIn, uint ethQty0, uint usmQty0, uint debtRatio0)
        internal view returns (uint ethOut)
    {
        // Burn FUM at a sliding-down FUM price:
        uint fumQty0 = fum.totalSupply();
        uint fumPrice0 = fumPrice(Side.Sell, ethUsmPrice, ethQty0, usmQty0, fumQty0, buySellAdjustment());
        if (debtRatio0 == 0) {
            // No USM in the system - skip sliding-prices:
            ethOut = fumIn.wadMul(fumPrice0);
        } else {
            uint fumQty1 = fumQty0.sub(fumIn);

            // Math: see closely analogous comment in ethFromBurn() above.
            uint integralFirstPart = fumQty0.wadSquared().sub(fumQty1.wadSquared()).wadMul(fumPrice0.wadSquared());
            uint ethQty1 = ethQty0.wadSquared().sub(integralFirstPart.wadDiv(debtRatio0)).wadSqrt();
            ethOut = ethQty0.sub(ethQty1);
        }
    }

    /**
     * @notice The current min FUM buy price, equal to the stored value decayed by time since minFumBuyPriceTimestamp.
     * @return mfbp The minFumBuyPrice, in ETH terms
     */
    function minFumBuyPrice() public view returns (uint mfbp) {
        if (minFumBuyPriceStored.value != 0) {
            uint numHalvings = block.timestamp.sub(minFumBuyPriceStored.timestamp).wadDiv(MIN_FUM_BUY_PRICE_HALF_LIFE);
            uint decayFactor = numHalvings.wadHalfExp();
            mfbp = uint256(minFumBuyPriceStored.value).wadMul(decayFactor);
        }   // Otherwise just returns 0
    }

    /**
     * @notice The current buy/sell adjustment, equal to the stored value decayed by time since buySellAdjustmentTimestamp.  This
     * adjustment is intended as a measure of "how long-ETH recent user activity has been", so that we can slide price
     * accordingly: if recent activity was mostly long-ETH (fund() and burn()), raise FUM buy price/reduce USM sell price; if
     * recent activity was short-ETH (defund() and mint()), reduce FUM sell price/raise USM buy price.  We use "it reduced debt
     * ratio" as a rough proxy for "the operation was long-ETH".
     *
     * (There is one odd case: when debt ratio > 100%, a *short*-ETH mint() will actually reduce debt ratio.  This does no real
     * harm except to make fast-succession mint()s and fund()s in such > 100% cases a little more expensive than they would be.)
     *
     * @return adjustment The sliding-price buy/sell adjustment
     */
    function buySellAdjustment() public view returns (uint adjustment) {
        uint numHalvings = block.timestamp.sub(buySellAdjustmentStored.timestamp).wadDiv(BUY_SELL_ADJUSTMENT_HALF_LIFE);
        uint decayFactor = numHalvings.wadHalfExp(10);
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        adjustment = WAD.add(uint256(buySellAdjustmentStored.value).wadMul(decayFactor)).sub(decayFactor);
    }

    /** EXTERNAL VIEW FUNCTIONS */

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer() external view returns (int buffer) {
        int ethInPool = int(ethPool());
        buffer = ethInPool - int(usmToEth(latestPrice(), totalSupply()));
        require(buffer <= ethInPool, "Underflow error");
    }

    /**
     * @notice Convert ETH amount to USM using the latest oracle ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethAmount) external view returns (uint) {
        return ethToUsm(latestPrice(), ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest oracle ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint usmAmount) external view returns (uint) {
        return usmToEth(latestPrice(), usmAmount);
    }

    /**
     * @notice Calculate debt ratio.
     * @return ratio Debt ratio
     */
    function debtRatio() external view returns (uint ratio) {
        ratio = debtRatio(latestPrice(), ethPool(), totalSupply());
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(Side side) external view returns (uint price) {
        price = usmPrice(side, latestPrice());
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price FUM price in ETH terms
     */
    function fumPrice(Side side) external view returns (uint price) {
        price = fumPrice(side, latestPrice(), ethPool(), totalSupply(), fum.totalSupply(), buySellAdjustment());
    }
}
