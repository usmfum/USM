// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./ERC20WithOptOut.sol";
import "./oracles/Oracle.sol";
import "./Address.sol";
import "./Delegable.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "./MinOut.sol";


/**
 * @title USM
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 *
 * This abstract USM contract must be inherited by a concrete implementation, that also adds an Oracle implementation - eg, by
 * also inheriting a concrete Oracle implementation.  See USM (and MockUSM) for an example.
 *
 * We use this inheritance-based design (rather than the more natural, and frankly normally more correct, composition-based
 * design of storing the Oracle here as a variable), because inheriting the Oracle makes all the latestPrice()/refreshPrice()
 * calls *internal* rather than calls to a separate oracle contract (or multiple contracts) - which leads to a significant
 * saving in gas.
 */
contract USM is IUSM, Oracle, ERC20WithOptOut, Delegable {
    using Address for address payable;
    using WadMath for uint;

    event MinFumBuyPriceChanged(uint previous, uint latest);
    event BuySellAdjustmentChanged(uint previous, uint latest);
    event PriceChanged(uint previous, uint latest);

    uint public constant WAD = 10 ** 18;
    uint public constant HALF_WAD = WAD / 2;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                 // 80%
    uint public constant MIN_FUM_BUY_PRICE_HALF_LIFE = 1 days;          // Solidity for 1 * 24 * 60 * 60
    uint public constant BUY_SELL_ADJUSTMENT_HALF_LIFE = 1 minutes;     // Solidity for 1 * 60

    uint private constant UINT32_MAX = 2 ** 32 - 1;      // Should really be type(uint32).max, but that needs Solidity 0.6.8...
    uint private constant UINT224_MAX = 2 ** 224 - 1;    // Ditto, type(uint224).max
    uint private constant INT_MAX = 2**256 - 1;          // Ditto, type(int).max

    FUM public immutable fum;
    Oracle public immutable oracle;

    struct TimedValue {
        uint32 timestamp;
        uint224 value;
    }

    TimedValue public storedPrice;
    TimedValue public storedMinFumBuyPrice;
    TimedValue public storedBuySellAdjustment = TimedValue({ timestamp: 0, value: uint224(WAD) });

    constructor(Oracle oracle_) public
        ERC20WithOptOut("Minimal USD", "USM")
    {
        oracle = oracle_;
        fum = new FUM(this);
        optedOut[address(oracle_)] = true;
    }

    /** PUBLIC AND EXTERNAL TRANSACTIONAL FUNCTIONS **/

    /**
     * @notice Mint new USM, sending it to the given address, and only if the amount minted >= minUsmOut.  The amount of ETH is
     * passed in as msg.value.
     * @param to address to send the USM to.
     * @param minUsmOut Minimum accepted USM for a successful mint.
     */
    function mint(address to, uint minUsmOut) external payable override returns (uint usmOut) {
        usmOut = _mintUsm(to, minUsmOut);
    }

    /**
     * @dev Burn USM in exchange for ETH.
     * @param from address to deduct the USM from.
     * @param to address to send the ETH to.
     * @param usmToBurn Amount of USM to burn.
     * @param minEthOut Minimum accepted ETH for a successful burn.
     */
    function burn(address from, address payable to, uint usmToBurn, uint minEthOut)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        ethOut = _burnUsm(from, to, usmToBurn, minEthOut);
    }

    /**
     * @notice Funds the pool with ETH, minting new FUM and sending it to the given address, but only if the amount minted >=
     * minFumOut.  The amount of ETH is passed in as msg.value.
     * @param to address to send the FUM to.
     * @param minFumOut Minimum accepted FUM for a successful fund.
     */
    function fund(address to, uint minFumOut) external payable override returns (uint fumOut) {
        fumOut = _fundFum(to, minFumOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param from address to deduct the FUM from.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defund(address from, address payable to, uint fumToBurn, uint minEthOut)
        external override
        onlyHolderOrDelegate(from, "Only holder or delegate")
        returns (uint ethOut)
    {
        ethOut = _defundFum(from, to, fumToBurn, minEthOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM from an arbitrary address in exchange for equivalent ETH from the pool.
     * Called only by the FUM contract, when FUM is sent to it.
     * @param from address to deduct the FUM from.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defundFromFUM(address from, address payable to, uint fumToBurn, uint minEthOut)
        external override
        returns (uint ethOut)
    {
        require(msg.sender == address(fum), "Restricted to FUM");
        ethOut = _defundFum(from, to, fumToBurn, minEthOut);
    }

    function refreshPrice() public virtual override returns (uint price, uint updateTime) {
        uint adjustment;
        bool priceChanged;
        (price, updateTime, adjustment, priceChanged) = _refreshPrice();
        if (priceChanged) {
            require(updateTime <= UINT32_MAX, "updateTime overflow");
            require(price <= UINT224_MAX, "price overflow");
            storedPrice.timestamp = uint32(updateTime);
            storedPrice.value = uint224(price);

            require(adjustment <= UINT224_MAX, "adjustment overflow");
            storedBuySellAdjustment.timestamp = uint32(block.timestamp);
            storedBuySellAdjustment.value = uint224(adjustment);
        }
    }

    /**
     * @notice If anyone sends ETH here, assume they intend it as a `mint`.
     * If decimals 8 to 11 (included) of the amount of Ether received are `0000` then the next 7 will
     * be parsed as the minimum Ether price accepted, with 2 digits before and 5 digits after the comma.
     */
    receive() external payable {
        _mintUsm(msg.sender, MinOut.parseMinTokenOut(msg.value));
    }

    /**
     * @notice If a user sends USM tokens directly to this contract (or to the FUM contract), assume they intend it as a `burn`.
     * If using `transfer`/`transferFrom` as `burn`, and if decimals 8 to 11 (included) of the amount transferred received
     * are `0000` then the next 7 will be parsed as the maximum USM price accepted, with 5 digits before and 2 digits after the comma.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override noOptOut(recipient) returns (bool) {
        if (recipient == address(this) || recipient == address(fum) || recipient == address(0)) {
            _burnUsm(sender, payable(sender), amount, MinOut.parseMinEthOut(amount));
        } else {
            super._transfer(sender, recipient, amount);
        }
        return true;
    }

    /** INTERNAL TRANSACTIONAL FUNCTIONS */

    function _mintUsm(address to, uint minUsmOut) internal returns (uint usmOut)
    {
        // 1. Check that fund() has been called first - no minting before funding:
        uint rawEthInPool = ethPool();
        uint ethInPool = rawEthInPool - msg.value;   // Backing out the ETH just received, which our calculations should ignore
        require(ethInPool > 0, "Fund before minting");

        // 2. Calculate usmOut:
        (uint ethUsdPrice0,, uint adjustment0, ) = _refreshPrice();
        uint adjShrinkFactor;
        (usmOut, adjShrinkFactor) = usmFromMint(ethUsdPrice0, msg.value, ethInPool, adjustment0);
        require(usmOut >= minUsmOut, "Limit not reached");

        // 3. Update storedBuySellAdjustment and mint the user's new USM:
        _storeBuySellAdjustment(adjustment0.wadMulDown(adjShrinkFactor));
        _storePrice(ethUsdPrice0.wadMulDown(adjShrinkFactor));
        _mint(to, usmOut);
    }

    function _burnUsm(address from, address payable to, uint usmToBurn, uint minEthOut) internal returns (uint ethOut)
    {
        // 1. Calculate ethOut:
        (uint ethUsdPrice0,, uint adjustment0, ) = _refreshPrice();
        uint ethInPool = ethPool();
        uint adjGrowthFactor;
        (ethOut, adjGrowthFactor) = ethFromBurn(ethUsdPrice0, usmToBurn, ethInPool, adjustment0);
        require(ethOut >= minEthOut, "Limit not reached");

        // 2. Burn the input USM, update storedBuySellAdjustment, and return the user's ETH:
        uint newDebtRatio = debtRatio(ethUsdPrice0, ethInPool - ethOut, totalSupply() - usmToBurn);
        require(newDebtRatio <= WAD, "Debt ratio > 100%");
        _burn(from, usmToBurn);
        _storeBuySellAdjustment(adjustment0.wadMulUp(adjGrowthFactor));
        _storePrice(ethUsdPrice0.wadMulUp(adjGrowthFactor));
        to.sendValue(ethOut);
    }

    function _fundFum(address to, uint minFumOut) internal returns (uint fumOut)
    {
        // 1. Refresh mfbp:
        (uint ethUsdPrice0,, uint adjustment0, ) = _refreshPrice();
        uint rawEthInPool = ethPool();
        uint ethInPool = rawEthInPool - msg.value;   // Backing out the ETH just received, which our calculations should ignore
        uint usmSupply = totalSupply();
        uint fumSupply = fum.totalSupply();
        _updateMinFumBuyPrice(ethUsdPrice0, ethInPool, usmSupply, fumSupply);

        // 2. Calculate fumOut:
        uint adjGrowthFactor;
        (fumOut, adjGrowthFactor) = fumFromFund(ethUsdPrice0, msg.value, ethInPool, usmSupply, fumSupply, adjustment0);
        require(fumOut >= minFumOut, "Limit not reached");

        // 3. Update storedBuySellAdjustment and mint the user's new FUM:
        _storeBuySellAdjustment(adjustment0.wadMulUp(adjGrowthFactor));
        _storePrice(ethUsdPrice0.wadMulUp(adjGrowthFactor));
        fum.mint(to, fumOut);
    }

    function _defundFum(address from, address payable to, uint fumToBurn, uint minEthOut) internal returns (uint ethOut)
    {
        // 1. Calculate ethOut:
        (uint ethUsdPrice0,, uint adjustment0, ) = _refreshPrice();
        uint ethInPool = ethPool();
        uint usmSupply = totalSupply();
        uint adjShrinkFactor;
        (ethOut, adjShrinkFactor) = ethFromDefund(ethUsdPrice0, fumToBurn, ethInPool, usmSupply, adjustment0);
        require(ethOut >= minEthOut, "Limit not reached");

        // 2. Burn the input FUM, update storedBuySellAdjustment, and return the user's ETH:
        uint newDebtRatio = debtRatio(ethUsdPrice0, ethInPool - ethOut, usmSupply);
        require(newDebtRatio <= MAX_DEBT_RATIO, "Debt ratio > max");
        fum.burn(from, fumToBurn);
        _storeBuySellAdjustment(adjustment0.wadMulDown(adjShrinkFactor));
        _storePrice(ethUsdPrice0.wadMulDown(adjShrinkFactor));
        to.sendValue(ethOut);
    }

    function _refreshPrice() internal returns (uint price, uint updateTime, uint adjustment, bool priceChanged) {
        (price, updateTime) = oracle.refreshPrice();
        adjustment = buySellAdjustment();
        priceChanged = updateTime > storedPrice.timestamp;
        if (priceChanged) {
            /**
             * This is a bit subtle.  We want to update the mid stored price to the oracle's fresh value, while updating
             * buySellAdjustment in such a way that the currently adjusted (more expensive than mid) side gets no
             * cheaper/more favorably priced for users.  Example:
             *
             * 1. storedPrice = $1,000, and buySellAdjustment = 1.02.  So, our current ETH buy price is $1,020, and our current
             *    ETH sell price is $1,000 (mid).
             * 2. The oracle comes back with a fresh price (newer updateTime) of $990.
             * 3. The currently adjusted price is buy price (ie, adj > 1).  So, we want to:
             *    a) Update storedPrice (mid) to $990.
             *    b) Update buySellAdj to ensure that buy price remains >= $1,020.
             * 4. We do this by upping buySellAdj 1.02 -> 1.0303.  Then the new buy price will remain $990 * 1.0303 = $1,020.
             *    The sell price will remain the unadjusted mid: formerly $1,000, now $990.
             *
             * Because the buySellAdjustment reverts to 1 in a few minutes, the new 3.03% buy premium is temporary: buy price
             * will revert to the $990 mid soon - unless the new mid is egregiously low, in which case buyers should push it
             * back up.  Eg, suppose the oracle gives us a glitchy price of $99.  Then new mid = $99, buySellAdj = 10.303, buy
             * price = $1,020, and the buy price will rapidly drop towards $99; but as it does so, users are incentivized to
             * step in and buy, eventually pushing mid back up to the real-world ETH market price (eg $990).
             *
             * In cases like this, our buySellAdj update has protected the system, by preventing users from getting any chance
             * to buy at the bogus $99 price.
             */
            if (adjustment > 1) {
                // max(1, old buy price / new mid price):
                adjustment = WAD.wadMax((uint(storedPrice.value)) * (adjustment / price));
            } else if (adjustment < 1) {
                // min(1, old sell price / new mid price):
                adjustment = WAD.wadMin((uint(storedPrice.value)) * (adjustment / price));
            }
        } else {
            (price, updateTime) = (storedPrice.value, storedPrice.timestamp);
        }
    }

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
    function _updateMinFumBuyPrice(uint ethUsdPrice, uint ethInPool, uint usmSupply, uint fumSupply) internal {
        uint previous = storedMinFumBuyPrice.value;
        uint debtRatio_ = debtRatio(ethUsdPrice, ethInPool, usmSupply);
        if (debtRatio_ <= MAX_DEBT_RATIO) {                 // We've dropped below (or were already below, whatev) max debt ratio
            if (previous != 0) {
                storedMinFumBuyPrice.timestamp = 0;         // Clear mfbp
                storedMinFumBuyPrice.value = 0;
                emit MinFumBuyPriceChanged(previous, 0);
            }
        } else if (previous == 0) {                         // We were < max debt ratio, but have now crossed above - so set mfbp
            // See reasoning in @dev comment above
            uint mfbp = (WAD - MAX_DEBT_RATIO).wadMulUp(ethInPool).wadDivUp(fumSupply);
            require(mfbp <= UINT224_MAX, "mfbp overflow");
            storedMinFumBuyPrice.timestamp = uint32(block.timestamp);
            storedMinFumBuyPrice.value = uint224(mfbp);
            emit MinFumBuyPriceChanged(previous, storedMinFumBuyPrice.value);
        }
    }

    /**
     * @notice Store the new ETH mid price after a price-moving operation.  Note that storedPrice.timestamp is *not* updated:
     * it refers to the time of the most recent *oracle* update, not of internal USM price updates by this function.
     */
    function _storePrice(uint newPrice) internal {
        uint previous = storedPrice.value;

        require(newPrice <= UINT224_MAX, "newPrice overflow");
        storedPrice.value = uint224(newPrice);
        emit PriceChanged(previous, newPrice);
    }

    /**
     * @notice Store the new buy/sell adjustment factor, as of the current block time, after a price-moving operation.
     */
    function _storeBuySellAdjustment(uint newAdjustment) internal {
        uint previous = storedBuySellAdjustment.value; // Not nec same as current buySellAdjustment(), due to the time decay!

        require(newAdjustment <= UINT224_MAX, "newAdjustment overflow");
        storedBuySellAdjustment.timestamp = uint32(block.timestamp);
        storedBuySellAdjustment.value = uint224(newAdjustment);
        emit BuySellAdjustmentChanged(previous, newAdjustment);
    }

    /** PUBLIC VIEW FUNCTIONS **/

    function latestPrice() public virtual override(IUSM, Oracle) view returns (uint price, uint updateTime) {
        (price, updateTime) = (storedPrice.value, storedPrice.timestamp);
    }

    function latestOraclePrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime) = oracle.latestPrice();
    }

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return pool ETH pool
     */
    function ethPool() public override view returns (uint pool) {
        pool = address(this).balance;
    }

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(uint ethUsdPrice, uint ethInPool, uint usmSupply, WadMath.Round upOrDown)
        public override pure returns (int buffer)
    {
        // Reverse the input upOrDown, since we're using it for usmToEth(), which will be *subtracted* from ethInPool below:
        WadMath.Round downOrUp = (upOrDown == WadMath.Round.Down ? WadMath.Round.Up : WadMath.Round.Down);
        buffer = int(ethInPool) - int(usmToEth(ethUsdPrice, usmSupply, downOrUp));
        require(buffer <= int(ethInPool), "Underflow error");
    }

    /**
     * @notice Calculate debt ratio for a given eth to USM price: ratio of the outstanding USM (amount of USM in total supply), to
     * the current ETH pool amount.
     * @return ratio Debt ratio
     */
    function debtRatio(uint ethUsdPrice, uint ethInPool, uint usmSupply) public override pure returns (uint ratio) {
        uint ethPoolValueInUsd = ethInPool.wadMulDown(ethUsdPrice);
        ratio = (ethInPool == 0 ? 0 : usmSupply.wadDivUp(ethPoolValueInUsd));
    }

    /**
     * @notice Convert ETH amount to USM using a ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethUsdPrice, uint ethAmount, WadMath.Round upOrDown) public override pure returns (uint usmOut) {
        usmOut = ethAmount.wadMul(ethUsdPrice, upOrDown);
    }

    /**
     * @notice Convert USM amount to ETH using a ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint ethUsdPrice, uint usmAmount, WadMath.Round upOrDown) public override pure returns (uint ethOut) {
        ethOut = usmAmount.wadDiv(ethUsdPrice, upOrDown);
    }

    function usmTotalSupply() public override view returns (uint supply) {
        supply = totalSupply();
    }

    function fumTotalSupply() public override view returns (uint supply) {
        supply = fum.totalSupply();
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(IUSM.Side side, uint ethUsdPrice, uint adjustment) public override view returns (uint price) {
        WadMath.Round upOrDown = (side == IUSM.Side.Buy ? WadMath.Round.Up : WadMath.Round.Down);
        price = usmToEth(ethUsdPrice, WAD, upOrDown);

        if ((side == IUSM.Side.Buy && adjustment < WAD) || (side == IUSM.Side.Sell && adjustment > WAD)) {
            price = price.wadDiv(adjustment, upOrDown);
        }
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before the price start sliding.
     * @return price FUM price in ETH terms
     */
    function fumPrice(IUSM.Side side, uint ethUsdPrice, uint ethInPool, uint usmSupply, uint fumSupply, uint adjustment)
        public override view returns (uint price)
    {
        WadMath.Round upOrDown = (side == IUSM.Side.Buy ? WadMath.Round.Up : WadMath.Round.Down);
        if (fumSupply == 0) {
            return usmToEth(ethUsdPrice, WAD, upOrDown);    // if no FUM issued yet, default fumPrice to 1 USD (in ETH terms)
        }
        int buffer = ethBuffer(ethUsdPrice, ethInPool, usmSupply, upOrDown);
        price = (buffer <= 0 ? 0 : uint(buffer).wadDiv(fumSupply, upOrDown));

        if (side == IUSM.Side.Buy) {
            if (adjustment > WAD) {
                price = price.wadMulUp(adjustment);
            }
            // Floor the buy price at minFumBuyPrice:
            uint mfbp = minFumBuyPrice();
            if (price < mfbp) {
                price = mfbp;
            }
        } else {
            if (adjustment < WAD) {
                price = price.wadMulDown(adjustment);
            }
        }
    }

    /**
     * @notice How much USM a minter currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     * @param ethIn The amount of ETH passed to mint()
     * @return usmOut The amount of USM to receive in exchange
     */
    function usmFromMint(uint ethUsdPrice0, uint ethIn, uint ethQty0, uint adjustment0)
        public view returns (uint usmOut, uint adjShrinkFactor)
    {
        // Create USM at a sliding-up USM price (ie, a sliding-down ETH price):
        uint usmBuyPrice0 = usmPrice(IUSM.Side.Buy, ethUsdPrice0, adjustment0);
        uint ethQty1 = ethQty0 + ethIn;
        //adjShrinkFactor = ethQty0.wadDivDown(ethQty1).wadSqrt();      // Another possible function we could use (same result)
        adjShrinkFactor = ethQty0.wadDivDown(ethQty1).wadExp(HALF_WAD);
        int log = ethQty1.wadDivDown(ethQty0).wadLog();
        require(log >= 0, "log underflow");
        usmOut = ethQty0.wadDivDown(usmBuyPrice0).wadMulDown(uint(log));
    }

    /**
     * @notice How much ETH a burner currently gets from burning usmIn USM, accounting for adjustment and sliding prices.
     * @param usmIn The amount of USM passed to burn()
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromBurn(uint ethUsdPrice0, uint usmIn, uint ethQty0, uint adjustment0)
        public view returns (uint ethOut, uint adjGrowthFactor)
    {
        // Burn USM at a sliding-down USM price (ie, a sliding-up ETH price):
        uint usmSellPrice0 = usmPrice(IUSM.Side.Sell, ethUsdPrice0, adjustment0);

        // Math: this is an integral - sum of all USM burned at a sliding price.  Follows the same mathematical invariant as
        // above: if debtRatio() *= k (here, k < 1), ETH price *= 1/k**2, ie, USM price in ETH terms *= k**2.
        // e_0 - e = e_0 - (e_0**2 * (e_0 - usp_0 * u_0 * (1 - (u / u_0)**3)))**(1/3)
        uint exponent = usmIn.wadMulUp(usmSellPrice0).wadDivUp(ethQty0);
        require(exponent <= INT_MAX, "exponent overflow");
        uint ethQty1 = ethQty0.wadDivUp(exponent.wadExp());
        ethOut = ethQty0 - ethQty1;
        adjGrowthFactor = ethQty0.wadDivUp(ethQty1).wadExp(HALF_WAD);
    }

    /**
     * @notice How much FUM a funder currently gets back for ethIn ETH, accounting for adjustment and sliding prices.
     * @param ethIn The amount of ETH passed to fund()
     * @return fumOut The amount of FUM to receive in exchange
     */
    function fumFromFund(uint ethUsdPrice0, uint ethIn, uint ethQty0, uint usmQty0, uint fumQty0, uint adjustment0)
        public view returns (uint fumOut, uint adjGrowthFactor)
    {
        if (ethQty0 == 0) {
            // No ETH in the system yet, which breaks our adjGrowthFactor calculation below - skip sliding-prices this time:
            adjGrowthFactor = WAD;
            uint fumBuyPrice0 = fumPrice(IUSM.Side.Buy, ethUsdPrice0, ethQty0, usmQty0, fumQty0, adjustment0);
            fumOut = ethIn.wadDivDown(fumBuyPrice0);
        } else {
            // Create FUM at a sliding-up FUM price:
            uint ethQty1 = ethQty0 + ethIn;
            uint effectiveUsmQty0 = usmQty0.wadMin(ethQty0.wadMulUp(ethUsdPrice0).wadMulUp(MAX_DEBT_RATIO));
            uint effectiveDebtRatio = debtRatio(ethUsdPrice0, ethQty0, effectiveUsmQty0);
            uint effectiveFumDelta = WAD.wadDivUp(WAD - effectiveDebtRatio);
            adjGrowthFactor = ethQty1.wadDivUp(ethQty0).wadExp(effectiveFumDelta / 2);
            fumOut = calcSlidingFumQty(ethUsdPrice0, ethIn, ethQty0, fumQty0, adjustment0, effectiveUsmQty0, adjGrowthFactor);
        }
    }

    function calcSlidingFumQty(uint ethUsdPrice0, uint ethIn, uint ethQty0, uint fumQty0, uint adjustment0,
                               uint effectiveUsmQty0, uint adjGrowthFactor)
        public pure returns (uint fumOut)
    {
        uint ethUsdPrice1 = ethUsdPrice0.wadMulUp(adjGrowthFactor);
        uint avgFumBuyPrice = adjustment0.wadMulUp(
            (ethQty0 - effectiveUsmQty0.wadDivDown(ethUsdPrice1)).wadDivUp(fumQty0));
        fumOut = ethIn.wadDivDown(avgFumBuyPrice);
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustment and sliding prices.
     * @param fumIn The amount of FUM passed to defund()
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromDefund(uint ethUsdPrice0, uint fumIn, uint ethQty0, uint usmQty0, uint adjustment0)
        public view returns (uint ethOut, uint adjShrinkFactor)
    {
        // Burn FUM at a sliding-down FUM price:
        uint fumQty0 = fum.totalSupply();
        uint debtRatio0 = debtRatio(ethUsdPrice0, ethQty0, usmQty0);
        uint fumDelta = WAD.wadDivUp(WAD - debtRatio0);
        uint avgFumSellPrice = calcAverageFumSellPrice(ethUsdPrice0, fumIn, ethQty0, usmQty0, fumQty0, adjustment0, fumDelta);
        ethOut = fumIn.wadMulDown(avgFumSellPrice);
        uint ethQty1 = ethQty0 - ethOut;
        adjShrinkFactor = ethQty1.wadDivUp(ethQty0).wadExp(fumDelta / 2);
    }

    function calcAverageFumSellPrice(uint ethUsdPrice0, uint fumIn, uint ethQty0, uint usmQty0, uint fumQty0, uint adjustment0,
                                     uint fumDelta)
        public view returns (uint avgFumSellPrice)
    {
        uint fumSellPrice0 = fumPrice(IUSM.Side.Sell, ethUsdPrice0, ethQty0, usmQty0, fumQty0, adjustment0);

        // First obtain a pessimistic upper bound on how large the adjShrinkFactor could be - pessimistic since the more the
        // adjustment shrinks, the more our sell price slides (down) away from us.  The more the ETH pool decreases, the more
        // the adjShrinkFactor drops.  And the amount by which the ETH pool would drop if our entire defund was at the starting
        // fumSellPrice0, is an upper bound on how much the pool could shrink.  Therefore, the adjShrinkFactor implied by that
        // maximum ETH pool reduction, is an upper bound on the actual adjShrinkFactor of this defund() call:
        uint lowerBoundEthQty1 = ethQty0 - fumIn.wadMulUp(fumSellPrice0);
        uint lowerBoundAdjShrinkFactor = lowerBoundEthQty1.wadDivDown(ethQty0).wadExp(fumDelta / 2);
        uint lowerBoundEthUsdPrice1 = ethUsdPrice0.wadMulDown(lowerBoundAdjShrinkFactor);

        // Using this ending ETH mid price lowerBoundEthUsdPrice1, we can calc the actual average FUM sell price of the defund:
        avgFumSellPrice = fumPrice(IUSM.Side.Sell, lowerBoundEthUsdPrice1, ethQty0, usmQty0, fumQty0, adjustment0);
    }

    /**
     * @notice The current min FUM buy price, equal to the stored value decayed by time since minFumBuyPriceTimestamp.
     * @return mfbp The minFumBuyPrice, in ETH terms
     */
    function minFumBuyPrice() public view returns (uint mfbp) {
        if (storedMinFumBuyPrice.value != 0) {
            uint numHalvings = (block.timestamp - storedMinFumBuyPrice.timestamp).wadDivDown(MIN_FUM_BUY_PRICE_HALF_LIFE);
            uint decayFactor = numHalvings.wadHalfExp();
            mfbp = uint256(storedMinFumBuyPrice.value).wadMulUp(decayFactor);
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
    function buySellAdjustment() public override view returns (uint adjustment) {
        uint numHalvings = (block.timestamp - storedBuySellAdjustment.timestamp).wadDivDown(BUY_SELL_ADJUSTMENT_HALF_LIFE);
        uint decayFactor = numHalvings.wadHalfExp(10);
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        adjustment = WAD + uint256(storedBuySellAdjustment.value).wadMulDown(decayFactor) - decayFactor;
    }
}
