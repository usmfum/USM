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

    enum Side {Buy, Sell}

    event MinFumBuyPriceChanged(uint previous, uint latest);
    event MintBurnAdjustmentChanged(uint previous, uint latest);
    event FundDefundAdjustmentChanged(uint previous, uint latest);

    uint public constant WAD = 10 ** 18;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                 // 80%
    uint public constant MIN_FUM_BUY_PRICE_HALF_LIFE = 24 * 60 * 60;    // 1 day
    uint public constant BUY_SELL_ADJUSTMENTS_HALF_LIFE = 60;           // 1 minute

    IOracle public oracle;
    IERC20 public eth;
    FUM public fum;

    struct TimedValue {
        uint32 timestamp;
        uint224 value;
    }

    TimedValue public minFumBuyPriceStored;
    TimedValue public mintBurnAdjustmentStored = TimedValue({ timestamp: 0, value: uint224(WAD) });
    TimedValue public fundDefundAdjustmentStored = TimedValue({ timestamp: 0, value: uint224(WAD) });

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
     * @return USM minted
     */
    function mint(address from, address to, uint ethIn)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint)
    {
        // First calculate:
        uint usmOut;
        uint ethPoolGrowthFactor;
        (usmOut, ethPoolGrowthFactor) = usmFromMint(ethIn);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        _updateMintBurnAdjustment(mintBurnAdjustment().wadDiv(ethPoolGrowthFactor.wadSquared()));
        _mint(to, usmOut);
        return usmOut;
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
        // First calculate:
        uint ethOut;
        uint ethPoolShrinkFactor;
        (ethOut, ethPoolShrinkFactor) = ethFromBurn(usmToBurn);

        // Then update state:
        _burn(from, usmToBurn);
        _updateMintBurnAdjustment(mintBurnAdjustment().wadDiv(ethPoolShrinkFactor.wadSquared()));
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        require(debtRatio() <= WAD, "Debt ratio too high");
        return ethOut;
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
        // First refresh mfbp:
        _updateMinFumBuyPrice();

        // Then calculate:
        uint fumOut;
        uint ethPoolGrowthFactor;
        (fumOut, ethPoolGrowthFactor) = fumFromFund(ethIn);

        // Then update state:
        require(eth.transferFrom(from, address(this), ethIn), "ETH transfer fail");
        if (ethPoolGrowthFactor != type(uint).max) {
            _updateFundDefundAdjustment(fundDefundAdjustment().wadMul(ethPoolGrowthFactor.wadSquared()));
        }
        fum.mint(to, fumOut);
        return fumOut;
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
        // First calculate:
        uint ethOut;
        uint ethPoolShrinkFactor;
        (ethOut, ethPoolShrinkFactor) = ethFromDefund(fumToBurn);

        // Then update state:
        fum.burn(from, fumToBurn);
        _updateFundDefundAdjustment(fundDefundAdjustment().wadMul(ethPoolShrinkFactor.wadSquared()));
        require(eth.transfer(to, ethOut), "ETH transfer fail");
        require(debtRatio() <= MAX_DEBT_RATIO, "Max debt ratio breach");
        return ethOut;
    }

    /** PUBLIC FUNCTIONS **/

    /**
     * @notice Regular transfer, disallowing transfers to this contract.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient != address(this) && recipient != address(fum), "Don't transfer here");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract)
     *
     * @return ETH pool
     */
    function ethPool() public view returns (uint) {
        return eth.balanceOf(address(this));
    }

    /**
     * @notice Calculate the amount of ETH in the buffer
     *
     * @return ETH buffer
     */
    function ethBuffer() public view returns (int) {
        uint pool = ethPool();
        int buffer = int(pool) - int(usmToEth(totalSupply()));
        require(buffer <= int(pool), "Underflow error");
        return buffer;
    }

    /**
     * @notice Calculate debt ratio: ratio of the outstanding USM (amount of USM in total supply), to the current ETH pool amount.
     *
     * @return Debt ratio.
     */
    function debtRatio() public view returns (uint) {
        uint pool = ethPool();
        if (pool == 0) {
            return MAX_DEBT_RATIO;
        }
        return totalSupply().wadDiv(ethToUsm(pool));
    }

    /**
     * @notice Calculates the *marginal* price of USM (in ETH terms) - that is, of the next unit, before the price start sliding
     */
    function usmPrice(Side side) public view returns (uint) {
        uint price = usmToEth(WAD);
        if (side == Side.Buy) {
            price = price.wadMul(WAD.wadMax(mintBurnAdjustment()));
            price = price.wadMul(WAD.wadMax(fundDefundAdjustment()));
        } else {
            price = price.wadMul(WAD.wadMin(mintBurnAdjustment()));
            price = price.wadMul(WAD.wadMin(fundDefundAdjustment()));
        }
        return price;
    }

    /**
     * @notice Calculates the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before the price start sliding
     */
    function fumPrice(Side side) public view returns (uint) {
        uint fumTotalSupply = fum.totalSupply();

        if (fumTotalSupply == 0) {
            return usmToEth(WAD); // if no FUM have been issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        int buffer = ethBuffer();
        uint price = (buffer < 0 ? 0 : uint(buffer).wadDiv(fumTotalSupply));
        if (side == Side.Buy) {
            price = price.wadMul(WAD.wadMax(mintBurnAdjustment()));
            price = price.wadMul(WAD.wadMax(fundDefundAdjustment()));
            // Floor the buy price at minFumBuyPrice:
            price = price.wadMax(minFumBuyPrice());
        } else {
            price = price.wadMul(WAD.wadMin(mintBurnAdjustment()));
            price = price.wadMul(WAD.wadMin(fundDefundAdjustment()));
        }
        return price;
    }

    /**
     * @notice The current min FUM buy price, equal to the stored value decayed by time since minFumBuyPriceTimestamp.
     */
    function minFumBuyPrice() public view returns (uint) {
        if (minFumBuyPriceStored.value == 0) {
            return 0;
        }
        uint numHalvings = block.timestamp.sub(minFumBuyPriceStored.timestamp).wadDiv(MIN_FUM_BUY_PRICE_HALF_LIFE);
        uint decayFactor = numHalvings.wadHalfExp();
        return uint256(minFumBuyPriceStored.value).wadMul(decayFactor);
    }

    /**
     * @notice The current mint-burn adjustment, equal to the stored value decayed by time since mintBurnAdjustmentTimestamp.
     */
    function mintBurnAdjustment() public view returns (uint) {
        uint numHalvings = block.timestamp.sub(mintBurnAdjustmentStored.timestamp).wadDiv(BUY_SELL_ADJUSTMENTS_HALF_LIFE);
        uint decayFactor = numHalvings.wadHalfExp(10);
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        return WAD.add(uint256(mintBurnAdjustmentStored.value).wadMul(decayFactor)).sub(decayFactor);
    }

    /**
     * @notice The current fund-defund adjustment, equal to the stored value decayed by time since fundDefundAdjustmentTimestamp.
     */
    function fundDefundAdjustment() public view returns (uint) {
        uint numHalvings = block.timestamp.sub(fundDefundAdjustmentStored.timestamp).wadDiv(BUY_SELL_ADJUSTMENTS_HALF_LIFE);
        uint decayFactor = numHalvings.wadHalfExp(10);
        return WAD.add(uint256(fundDefundAdjustmentStored.value).wadMul(decayFactor)).sub(decayFactor);
    }

    /**
     * @notice How much USM a minter currently gets back for ethIn ETH, accounting for adjustments and sliding prices.
     *
     * @param ethIn The amount of ETH passed to mint().
     * @return The amount of USM, and the factor by which the ethPool grew (eg, 1.2 * WAD = 1.2x).
     */
    function usmFromMint(uint ethIn) public view returns (uint, uint) {
        // Mint USM at a sliding-up USM price (ie, at a sliding-down ETH price).  **BASIC RULE:** anytime ethPool() changes by
        // factor k, ETH price changes by factor 1/k**2 (ie, USM price, in ETH terms, changes by factor k**2).  (Earlier versions
        // of this logic scaled ETH price by 1/k, not 1/k**2; but that results in gas-heavy calls to log()/exp().)
        uint initialUsmPrice = usmPrice(Side.Buy);
        uint pool = ethPool();
        uint ethPoolGrowthFactor = pool.add(ethIn).wadDiv(pool);
        // Math: this is an integral - sum of all USM minted at a sliding-down ETH price:
        uint usmOut = pool.wadDiv(initialUsmPrice).wadMul(WAD.sub(WAD.wadDiv(ethPoolGrowthFactor)));
        return (usmOut, ethPoolGrowthFactor);
    }

    /**
     * @notice How much ETH a burner currently gets from burning usmIn USM, accounting for adjustments and sliding prices.
     *
     * @param usmIn The amount of USM passed to burn().
     * @return The amount of ETH, and the factor by which the ethPool shrank.
     */
    function ethFromBurn(uint usmIn) public view returns (uint, uint) {
        // Burn at a sliding-up price:
        uint initialUsmPrice = usmPrice(Side.Sell);
        uint pool = ethPool();
        // Math: this is an integral - sum of all USM burned at a sliding price.  Follows the same mathematical invariant as
        // above: if ethPool() *= k, ETH price *= 1/k**2, ie, USM price in ETH terms *= k**2.
        uint ethOut = WAD.wadDiv(WAD.wadDiv(pool).add(WAD.wadDiv(usmIn.wadMul(initialUsmPrice))));
        uint ethPoolShrinkFactor = pool.sub(ethOut).wadDiv(pool);
        return (ethOut, ethPoolShrinkFactor);
    }

    /**
     * @notice How much FUM a funder currently gets back for ethIn ETH, accounting for adjustments and sliding prices.
     *
     * @param ethIn The amount of ETH passed to fund().
     * @return The amount of FUM, and the factor by which the ethPool grew.
     */
    function fumFromFund(uint ethIn) public view returns (uint, uint) {
        // Create FUM at a sliding-up price:
        uint initialFumPrice = fumPrice(Side.Buy);
        uint pool = ethPool();
        uint ethPoolGrowthFactor;
        uint fumOut;
        if (pool == 0 ) {
            // This is our first ETH added, so an "ethPoolGrowthFactor" makes no sense - skip sliding-prices for this first call:
            ethPoolGrowthFactor = type(uint).max;
            fumOut = ethIn.wadDiv(initialFumPrice);
        } else {
            ethPoolGrowthFactor = pool.add(ethIn).wadDiv(pool);
            // Math: see closely analogous comment in usmFromMint() above.
            fumOut = pool.wadDiv(initialFumPrice).wadMul(WAD.sub(WAD.wadDiv(ethPoolGrowthFactor)));
        }
        return (fumOut, ethPoolGrowthFactor);
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustments and sliding prices.
     *
     * @param fumIn The amount of FUM passed to defund().
     * @return The amount of ETH, and the factor by which the ethPool shrank.
     */
    function ethFromDefund(uint fumIn) public view returns (uint, uint) {
        uint initialFumPrice = fumPrice(Side.Sell);
        uint pool = ethPool();
        // Math: see closely analogous comment in ethFromBurn() above.
        uint ethOut = WAD.wadDiv(WAD.wadDiv(pool).add(WAD.wadDiv(fumIn.wadMul(initialFumPrice))));
        uint ethPoolShrinkFactor = pool.sub(ethOut).wadDiv(pool);
        return (ethOut, ethPoolShrinkFactor);
    }

    /**
     * @notice Convert ETH amount to USM using the latest price of USM
     * in ETH.
     *
     * @param ethAmount The amount of ETH to convert.
     * @return The amount of USM.
     */
    function ethToUsm(uint ethAmount) public view returns (uint) {
        return _oraclePrice().wadMul(ethAmount);
    }

    /**
     * @notice Convert USM amount to ETH using the latest price of USM
     * in ETH.
     *
     * @param usmAmount The amount of USM to convert.
     * @return The amount of ETH.
     */
    function usmToEth(uint usmAmount) public view returns (uint) {
        return usmAmount.wadDiv(_oraclePrice());
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
     * @notice Updates the mint-burn adjustment factor, as of the current block time.
     */
    function _updateMintBurnAdjustment(uint adjustment) internal {
        uint previous = mintBurnAdjustmentStored.value;
        mintBurnAdjustmentStored = TimedValue({
            timestamp: uint32(block.timestamp),
            value: uint224(adjustment)
        });

        emit MintBurnAdjustmentChanged(previous, mintBurnAdjustmentStored.value);
    }

    /**
     * @notice Updates the fund-defund adjustment factor, as of the current block time.
     */
    function _updateFundDefundAdjustment(uint adjustment) internal {
        uint previous = fundDefundAdjustmentStored.value;
        fundDefundAdjustmentStored = TimedValue({
            timestamp: uint32(block.timestamp),
            value: uint224(adjustment)
        });

        emit FundDefundAdjustmentChanged(previous, fundDefundAdjustmentStored.value);
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     *
     * @return price
     */
    function _oraclePrice() internal view returns (uint) {
        // Needs a convertDecimal(oracle.decimalShift(), UNIT) function.
        return oracle.latestPrice().wadDiv(10 ** oracle.decimalShift());
    }
}
