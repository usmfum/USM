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
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is IUSM, ERC20Permit, Delegable {
    using SafeMath for uint;
    using WadMath for uint;

    enum Side {Buy, Sell}

    event MinFumBuyPriceChanged(uint previous, uint latest);
    event BuySellAdjustmentChanged(uint previous, uint latest);

    uint public constant WAD = 10 ** 18;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                 // 80%
    uint public constant MIN_FUM_BUY_PRICE_HALF_LIFE = 24 * 60 * 60;    // 1 day
    uint public constant BUY_SELL_ADJUSTMENT_HALF_LIFE = 60;            // 1 minute

    IOracle public oracle;
    IERC20 public eth;
    FUM public fum;

    struct TimedValue {
        uint32 timestamp;
        uint224 value;
    }

    TimedValue public minFumBuyPriceStored;
    TimedValue public buySellAdjustmentStored = TimedValue({ timestamp: 0, value: uint224(WAD) });

    /**
     * @param oracle_ Address of the oracle
     */
    constructor(address oracle_, address eth_) public ERC20Permit("Minimal USD", "USM") {
        fum = new FUM(address(this));
        oracle = IOracle(oracle_);
        eth = IERC20(eth_);
    }

    /** EXTERNAL FUNCTIONS **/

    /**
     * @notice Mint ETH for USM with checks and asset transfers. Uses msg.value as the ETH deposit.
     * FUM needs to be funded before USM can be minted.
     * @param ethIn Amount of wrapped Ether to use for minting USM.
     * @return usmOut USM minted
     */
    function mint(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint usmOut)
    {
        // First check that fund() has been called first - no minting before funding:
        require(ethPool() > 0, "Fund before minting");

        // Then calculate:
        uint oldDebtRatio = debtRatio();
        usmOut = usmFromMint(ethIn);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        _mint(to, usmOut);
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio);
    }

    /**
     * @notice Burn USM for ETH with checks and asset transfers.
     *
     * @param usmToBurn Amount of USM to burn.
     * @return ethOut ETH sent
     */
    function burn(address from, address to, uint usmToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        // First calculate:
        uint oldDebtRatio = debtRatio();
        ethOut = ethFromBurn(usmToBurn);

        // Then update state:
        _burn(from, usmToBurn);
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        require(debtRatio() <= WAD, "Debt ratio too high");
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio);
    }

    /**
     * @notice Funds the pool with ETH, minting FUM at its current price and considering if the debt ratio goes from under to over
     * @param ethIn Amount of wrapped Ether to use for minting FUM.
     * @return fumOut FUM sent
     */
    function fund(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint fumOut)
    {
        // First refresh mfbp:
        _updateMinFumBuyPrice();

        // Then calculate:
        uint oldDebtRatio = (ethPool() == 0 ? 0 : debtRatio());     // Handling the initial case where the pool is empty
        fumOut = fumFromFund(ethIn);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        fum.mint(to, fumOut);
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH from the pool
     * @param fumToBurn Amount of FUM to burn.
     * @return ethOut ETH sent
     */
    function defund(address from, address to, uint fumToBurn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        // First calculate:
        uint oldDebtRatio = debtRatio();
        ethOut = ethFromDefund(fumToBurn);

        // Then update state:
        fum.burn(from, fumToBurn);
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        require(debtRatio() <= MAX_DEBT_RATIO, "Max debt ratio breach");
        _updateBuySellAdjustmentIfNeeded(oldDebtRatio);
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Regular transfer, disallowing transfers to this contract.
     * @return success transfer success
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool success) {
        require(recipient != address(this) && recipient != address(fum), "Don't transfer here");
        _transfer(_msgSender(), recipient, amount);
        success = true;
    }

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract)
     *
     * @return pool ETH pool
     */
    function ethPool() public view returns (uint pool) {
        pool = eth.balanceOf(address(this));
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return buffer ETH buffer
     */
    function ethBuffer() public view returns (int buffer) {
        uint pool = ethPool();
        buffer = int(pool) - int(usmToEth(totalSupply()));
        require(buffer <= int(pool), "Underflow error");
    }

    /**
     * @notice Calculate debt ratio: ratio of the outstanding USM (amount of USM in total supply), to the current ETH pool amount.
     *
     * @return ratio Debt ratio.
     */
    function debtRatio() public view returns (uint ratio) {
        uint pool = ethPool();
        ratio = (pool == 0 ? 0 : totalSupply().wadDiv(ethToUsm(pool)));
    }

    /**
     * @notice Calculates the *marginal* price of USM (in ETH terms) - that is, of the next unit, before the price start sliding
     * @return price USM price
     */
    function usmPrice(Side side) public view returns (uint price) {
        price = usmToEth(WAD);
        if (side == Side.Buy) {
            price = price.wadMul(WAD.wadMax(buySellAdjustment()));
        } else {
            price = price.wadMul(WAD.wadMin(buySellAdjustment()));
        }
    }

    /**
     * @notice Calculates the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before the price start sliding
     * @return price FUM price
     */
    function fumPrice(Side side) public view returns (uint price) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToEth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        int buffer = ethBuffer();
        price = (buffer < 0 ? 0 : uint(buffer).wadDiv(fumTotalSupply));
        if (side == Side.Buy) {
            price = price.wadMul(WAD.wadMax(buySellAdjustment()));
            // Floor the buy price at minFumBuyPrice:
            price = price.wadMax(minFumBuyPrice());
        } else {
            price = price.wadMul(WAD.wadMin(buySellAdjustment()));
        }
    }

    /**
     * @notice The current min FUM buy price, equal to the stored value decayed by time since minFumBuyPriceTimestamp.
     * @return mfbp the minFumBuyPrice, in ETH terms
     */
    function minFumBuyPrice() public view returns (uint mfbp) {
        if (minFumBuyPriceStored.value != 0) {
            uint numHalvings = block.timestamp.sub(minFumBuyPriceStored.timestamp).wadDiv(MIN_FUM_BUY_PRICE_HALF_LIFE);
            uint decayFactor = numHalvings.wadHalfExp();
            mfbp = uint256(minFumBuyPriceStored.value).wadMul(decayFactor);
        }   // Otherwise just returns 0
    }

    /**
     * @notice The current buy/sell adjustment, equal to the stored value decayed by time since buySellAdjustmentTimestamp.
     * @return adjustment the sliding-price buy/sell adjustment
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

    /**
     * @notice How much USM a minter currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     *
     * @param ethIn The amount of ETH passed to mint().
     * @return usmOut The amount of USM, and the factor by which the ethPool grew (eg, 1.2 * WAD = 1.2x).
     */
    function usmFromMint(uint ethIn) public view returns (uint usmOut) {
        // Mint USM at a sliding-up USM price (ie, at a sliding-down ETH price).  **BASIC RULE:** anytime debtRatio() changes by
        // factor k (here > 1), ETH price changes by factor 1/k (ie, USM price, in ETH terms, changes by factor k).  (Earlier
        // versions of this logic scaled ETH price based on the change in ethPool(), or change in ethPool() squared: the latter
        // gives simpler math - no sqrt() - but doesn't let mint/burn offset fund/defund, which using debtRatio() nicely does.)
        uint usmPrice0 = usmPrice(Side.Buy);
        uint debtRatio0 = debtRatio();
        if (debtRatio0 == 0) {
            // No USM in the system, so debtRatio() == 0 which breaks the integral below - skip sliding-prices this time:
            usmOut = ethIn.wadDiv(usmPrice0);
        } else {
            uint usmQty0 = totalSupply();
            uint ethQty0 = ethPool();
            uint ethQty1 = ethQty0.add(ethIn);

            // Math: this is an integral - sum of all USM minted at a sliding-down ETH price:
            uint integralFirstPart = debtRatio0.wadMul(ethQty1.wadSquared().sub(ethQty0.wadSquared()));
            uint usmQty1 = integralFirstPart.add(usmQty0.wadMul(usmPrice0).wadSquared()).wadSqrt().wadDiv(usmPrice0);
            usmOut = usmQty1.sub(usmQty0);
        }
    }

    /**
     * @notice How much ETH a burner currently gets from burning usmIn USM, accounting for adjustment and sliding prices.
     *
     * @param usmIn The amount of USM passed to burn().
     * @return ethOut The amount of ETH, and the factor by which the ethPool shrank.
     */
    function ethFromBurn(uint usmIn) public view returns (uint ethOut) {
        // Burn USM at a sliding-down USM price (ie, a sliding-up ETH price):
        uint usmPrice0 = usmPrice(Side.Sell);
        uint debtRatio0 = debtRatio();
        uint ethQty0 = ethPool();
        uint usmQty0 = totalSupply();
        uint usmQty1 = usmQty0.sub(usmIn);

        // Math: this is an integral - sum of all USM burned at a sliding price.  Follows the same mathematical invariant as
        // above: if debtRatio() *= k (here, k < 1), ETH price *= 1/k, ie, USM price in ETH terms *= k.
        uint integralFirstPart = usmQty0.wadSquared().sub(usmQty1.wadSquared()).wadMul(usmPrice0.wadSquared());
        uint ethQty1 = ethQty0.wadSquared().sub(integralFirstPart.wadDiv(debtRatio0)).wadSqrt();
        ethOut = ethQty0.sub(ethQty1);
    }

    /**
     * @notice How much FUM a funder currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     *
     * @param ethIn The amount of ETH passed to fund().
     * @return fumOut The amount of FUM, and the factor by which the ethPool grew.
     */
    function fumFromFund(uint ethIn) public view returns (uint fumOut) {
        // Create FUM at a sliding-up FUM price:
        uint fumPrice0 = fumPrice(Side.Buy);
        uint debtRatio0 = debtRatio();
        if (debtRatio0 == 0) {
            // No USM in the system - skip sliding-prices:
            fumOut = ethIn.wadDiv(fumPrice0);
        } else {
            uint fumQty0 = fum.totalSupply();
            uint ethQty0 = ethPool();
            uint ethQty1 = ethQty0.add(ethIn);

            // Math: see closely analogous comment in usmFromMint() above.
            uint integralFirstPart = debtRatio0.wadMul(ethQty1.wadSquared().sub(ethQty0.wadSquared()));
            uint fumQty1 = integralFirstPart.add(fumQty0.wadMul(fumPrice0).wadSquared()).wadSqrt().wadDiv(fumPrice0);
            fumOut = fumQty1.sub(fumQty0);
        }
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustment and sliding prices.
     *
     * @param fumIn The amount of FUM passed to defund().
     * @return ethOut The amount of ETH, and the factor by which the ethPool shrank.
     */
    function ethFromDefund(uint fumIn) public view returns (uint ethOut) {
        // Burn FUM at a sliding-down FUM price:
        uint fumPrice0 = fumPrice(Side.Sell);
        uint debtRatio0 = debtRatio();
        if (debtRatio0 == 0) {
            // No USM in the system - skip sliding-prices:
            ethOut = fumIn.wadMul(fumPrice0);
        } else {
            uint ethQty0 = ethPool();
            uint fumQty0 = fum.totalSupply();
            uint fumQty1 = fumQty0.sub(fumIn);

            // Math: see closely analogous comment in ethFromBurn() above.
            uint integralFirstPart = fumQty0.wadSquared().sub(fumQty1.wadSquared()).wadMul(fumPrice0.wadSquared());
            uint ethQty1 = ethQty0.wadSquared().sub(integralFirstPart.wadDiv(debtRatio0)).wadSqrt();
            ethOut = ethQty0.sub(ethQty1);
        }
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param ethAmount The amount of ETH to convert.
     * @return usmOut The amount of USM.
     */
    function ethToUsm(uint ethAmount) public view returns (uint usmOut) {
        usmOut = _oraclePrice().wadMul(ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param usmAmount The amount of USM to convert.
     * @return ethOut The amount of ETH.
     */
    function usmToEth(uint usmAmount) public view returns (uint ethOut) {
        ethOut = usmAmount.wadDiv(_oraclePrice());
    }

    /** INTERNAL FUNCTIONS */

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
    function _updateMinFumBuyPrice() internal {
        uint previous = minFumBuyPriceStored.value;
        if (debtRatio() <= MAX_DEBT_RATIO) {                // We've dropped below (or were already below, whatev) max debt ratio
            minFumBuyPriceStored = TimedValue({             // Clear mfbp
                timestamp: 0,
                value: 0
            });
        } else if (previous == 0) {                         // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            minFumBuyPriceStored = TimedValue({
                timestamp: uint32(block.timestamp),
                value: uint224(WAD.sub(MAX_DEBT_RATIO).wadMul(ethPool()).wadDiv(fum.totalSupply()))
            });
        }

        emit MinFumBuyPriceChanged(previous, minFumBuyPriceStored.value);
    }

    /**
     * @notice Updates the buy/sell adjustment factor, as of the current block time.
     */
    function _updateBuySellAdjustmentIfNeeded(uint oldDebtRatio) internal {
        if (oldDebtRatio != 0) {
            uint newDebtRatio = debtRatio();
            if (newDebtRatio != 0) {
                uint previous = buySellAdjustmentStored.value;
                uint adjustment = buySellAdjustment().wadMul(oldDebtRatio).wadDiv(newDebtRatio);
                buySellAdjustmentStored = TimedValue({
                    timestamp: uint32(block.timestamp),
                    value: uint224(adjustment)
                });

                emit BuySellAdjustmentChanged(previous, buySellAdjustmentStored.value);
            }
        }
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint price) {
        // Needs a convertDecimal(oracle.decimalShift(), UNIT) function.
        price = oracle.latestPrice().wadDiv(10 ** oracle.decimalShift());
    }
}
