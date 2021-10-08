// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./OptOutable.sol";
import "./oracles/Oracle.sol";
import "./Address.sol";
import "./WadMath.sol";
import "./FUM.sol";
import "./MinOut.sol";


/**
 * @title USM
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 * @notice Concept by Jacob Eliosoff (@jacob-eliosoff).
 */
contract USM is IUSM, ERC20Permit, OptOutable {
    using Address for address payable;
    using WadMath for uint;

    uint public constant WAD = 1e18;
    uint public constant FOUR_WAD = 4 * WAD;
    uint public constant BILLION = 1e9;
    uint public constant HALF_BILLION = BILLION / 2;
    uint public constant MAX_DEBT_RATIO = WAD * 8 / 10;                             // 80%
    uint public constant MIN_FUM_BUY_PRICE_DECAY_PER_SECOND = 999991977495368426;   // 1-sec decay equiv to halving in 1 day
    uint public constant BID_ASK_ADJUSTMENT_DECAY_PER_SECOND = 988514020352896135;  // 1-sec decay equiv to halving in 1 minute
    uint public constant BID_ASK_ADJUSTMENT_ZERO_OUT_PERIOD = 600;                  // After 10 min, adjustment just goes to 0

    uint public constant PREFUND_END_TIMESTAMP = 1635724800;                        // Midnight, morning of Nov 1, 2021
    uint public constant PREFUND_FUM_PRICE_IN_ETH = WAD / 4000;                     // Prefund FUM price: 1/4000 = 0.00025 ETH

    IFUM public immutable override fum;
    Oracle public immutable oracle;

    struct StoredState {
        uint32 timeSystemWentUnderwater;    // Time at which (we noticed) debt ratio went > MAX, or 0 if it's currently < MAX
        uint32 ethUsdPriceTimestamp;
        uint80 ethUsdPrice;                 // Stored in billionths, not WADs: so 123.456 is stored as 123,456,000,000
        uint32 bidAskAdjustmentTimestamp;
        uint80 bidAskAdjustment;            // Stored in billionths, not WADs
    }

    struct LoadedState {
        uint timeSystemWentUnderwater;
        uint ethUsdPriceTimestamp;
        uint ethUsdPrice;                   // This one is in WADs, not billionths
        uint bidAskAdjustmentTimestamp;
        uint bidAskAdjustment;              // WADs, not billionths
        uint ethPool;
        uint usmTotalSupply;
    }

    StoredState public storedState = StoredState({
        timeSystemWentUnderwater: 0, ethUsdPriceTimestamp: 0, ethUsdPrice: 0,
        bidAskAdjustmentTimestamp: 0, bidAskAdjustment: uint80(BILLION)         // Initialize adjustment to 1.0 (scaled by 1b)
    });

    constructor(Oracle oracle_, address[] memory optedOut_)
        ERC20Permit("Minimalist USD v1.0 - Test 4", "USMTest")
        OptOutable(optedOut_)
    {
        oracle = oracle_;
        fum = IFUM(address(new FUM(optedOut_)));
    }

    // ____________________ Modifiers ____________________

    /**
     * @dev Some operations are only allowed after the initial "prefund" (fixed-price funding) period.
     */
    modifier onlyAfterPrefund {
        require(!isDuringPrefund(), "Not allowed during prefund");
        _;
    }

    // ____________________ External transactional functions ____________________

    /**
     * @notice Mint new USM, sending it to the given address, and only if the amount minted >= `minUsmOut`.  The amount of ETH
     * is passed in as `msg.value`.
     * @param to address to send the USM to.
     * @param minUsmOut Minimum accepted USM for a successful mint.
     */
    function mint(address to, uint minUsmOut) external payable override returns (uint usmOut) {
        usmOut = _mintUsm(to, minUsmOut);
    }

    /**
     * @dev Burn USM in exchange for ETH.
     * @param to address to send the ETH to.
     * @param usmToBurn Amount of USM to burn.
     * @param minEthOut Minimum accepted ETH for a successful burn.
     */
    function burn(address payable to, uint usmToBurn, uint minEthOut)
        external override
        returns (uint ethOut)
    {
        ethOut = _burnUsm(msg.sender, to, usmToBurn, minEthOut);
    }

    /**
     * @notice Funds the pool with ETH, minting new FUM and sending it to the given address, but only if the amount minted >=
     * `minFumOut`.  The amount of ETH is passed in as `msg.value`.
     * @param to address to send the FUM to.
     * @param minFumOut Minimum accepted FUM for a successful fund.
     */
    function fund(address to, uint minFumOut) external payable override returns (uint fumOut) {
        fumOut = _fundFum(to, minFumOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defund(address payable to, uint fumToBurn, uint minEthOut)
        external override
        onlyAfterPrefund
        returns (uint ethOut)
    {
        ethOut = _defundFum(msg.sender, to, fumToBurn, minEthOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param from address to deduct the FUM from.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defundFrom(address from, address payable to, uint fumToBurn, uint minEthOut)
        external override
        onlyAfterPrefund
        returns (uint ethOut)
    {
        require(msg.sender == address(fum), "Only FUM");
        ethOut = _defundFum(from, to, fumToBurn, minEthOut);
    }

    /**
     * @notice If anyone sends ETH here, assume they intend it as a `mint`.  If decimals 8 to 11 (inclusive) of the amount of
     * ETH received are `0000`, then the next 7 will be parsed as the minimum number of USM accepted per input ETH, with the
     * 7-digit number interpreted as "hundredths of a USM".  See comments in `MinOut`.
     */
    receive() external payable {
        _mintUsm(msg.sender, MinOut.parseMinTokenOut(msg.value));
    }

    // ____________________ Internal ERC20 transactional functions ____________________

    /**
     * @notice If a user sends USM tokens directly to this contract (or to the FUM contract), assume they intend it as a
     * `burn`.  If using `transfer`/`transferFrom` as `burn`, and if decimals 8 to 11 (inclusive) of the amount transferred
     * are `0000`, then the next 7 will be parsed as the maximum number of USM tokens sent per ETH received, with the 7-digit
     * number interpreted as "hundredths of a USM".  See comments in `MinOut`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override noOptOut(recipient) returns (bool) {
        if (recipient == address(this) || recipient == address(fum) || recipient == address(0)) {
            _burnUsm(sender, payable(sender), amount, MinOut.parseMinEthOut(amount));
        } else {
            super._transfer(sender, recipient, amount);
        }
        return true;
    }

    // ____________________ Internal helper transactional functions (for functions above) ____________________

    function _mintUsm(address to, uint minUsmOut) internal returns (uint usmOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();
        ls.ethPool -= msg.value;    // Backing out the ETH just received, which our calculations should ignore

        // 2. Check that fund() has been called first - no minting before funding:
        require(ls.ethPool > 0, "Fund before minting");

        // 3. Refresh the oracle price (if available - see checkForFreshOraclePrice() below):
        (ls.ethUsdPrice, ls.ethUsdPriceTimestamp, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 4. Calculate usmOut:
        uint adjShrinkFactor;
        (usmOut, adjShrinkFactor) = usmFromMint(ls, msg.value);
        require(usmOut >= minUsmOut, "Limit not reached");

        // 5. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulDown(adjShrinkFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulDown(adjShrinkFactor);

        // 6. Store the updated state and mint the user's new USM:
        _storeState(ls);
        _mint(to, usmOut);
    }

    function _burnUsm(address from, address payable to, uint usmToBurn, uint minEthOut) internal returns (uint ethOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();

        // 2. Refresh the oracle price:
        (ls.ethUsdPrice, ls.ethUsdPriceTimestamp, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 3. Calculate ethOut:
        uint adjGrowthFactor;
        (ethOut, adjGrowthFactor) = ethFromBurn(ls, usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");

        // 4. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulUp(adjGrowthFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulUp(adjGrowthFactor);

        // 5. Burn the input USM, store the updated state, and return the user's ETH:
        _burn(from, usmToBurn);
        _storeState(ls);
        to.sendValue(ethOut);
    }

    function _fundFum(address to, uint minFumOut) internal returns (uint fumOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();
        ls.ethPool -= msg.value;    // Backing out the ETH just received, which our calculations should ignore

        // 2. Refresh the oracle price:
        (ls.ethUsdPrice, ls.ethUsdPriceTimestamp, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 3. Refresh timeSystemWentUnderwater, and replace ls.usmTotalSupply with the *effective* USM supply for FUM buys:
        uint debtRatio_;
        (ls.timeSystemWentUnderwater, ls.usmTotalSupply, debtRatio_) =
            checkIfUnderwater(ls.usmTotalSupply, ls.ethPool, ls.ethUsdPrice, ls.timeSystemWentUnderwater, block.timestamp);

        // 4. Calculate fumOut:
        uint fumSupply = fum.totalSupply();
        uint adjGrowthFactor;
        (fumOut, adjGrowthFactor) = fumFromFund(ls, fumSupply, msg.value, debtRatio_, isDuringPrefund());
        require(fumOut >= minFumOut, "Limit not reached");

        // 5. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulUp(adjGrowthFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulUp(adjGrowthFactor);

        // 6. Update the stored state and mint the user's new FUM:
        _storeState(ls);
        fum.mint(to, fumOut);
    }

    function _defundFum(address from, address payable to, uint fumToBurn, uint minEthOut) internal returns (uint ethOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();

        // 2. Refresh the oracle price:
        (ls.ethUsdPrice, ls.ethUsdPriceTimestamp, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 3. Calculate ethOut:
        uint fumSupply = fum.totalSupply();
        uint adjShrinkFactor;
        (ethOut, adjShrinkFactor) = ethFromDefund(ls, fumSupply, fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");

        // 4. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulDown(adjShrinkFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulDown(adjShrinkFactor);

        // 5. Check that the defund didn't leave debt ratio > MAX_DEBT_RATIO:
        uint newDebtRatio = debtRatio(ls.ethUsdPrice, ls.ethPool - ethOut, ls.usmTotalSupply);
        require(newDebtRatio <= MAX_DEBT_RATIO, "Debt ratio > max");

        // 6. Burn the input FUM, store the updated state, and return the user's ETH:
        fum.burn(from, fumToBurn);
        _storeState(ls);
        to.sendValue(ethOut);
    }

    /**
     * @notice Stores the current price, `bidAskAdjustment`, and `timeSystemWentUnderwater`.  Note that whereas most calls to
     * this function store a fresh `bidAskAdjustmentTimestamp`, most calls do *not* store a fresh `ethUsdPriceTimestamp`: the
     * latter isn't updated every time this is called with a new price, but only when the *oracle's* price is refreshed.  The
     * oracle price being "refreshed" is itself a subtle idea: see the comment in `Oracle.latestPrice()`.
     */
    function _storeState(LoadedState memory ls) internal {
        require(ls.ethUsdPriceTimestamp <= type(uint32).max, "ethUsdPriceTimestamp overflow");
        require(ls.bidAskAdjustmentTimestamp <= type(uint32).max, "bidAskAdjustmentTimestamp overflow");

        if (ls.timeSystemWentUnderwater != storedState.timeSystemWentUnderwater) {
            require(ls.timeSystemWentUnderwater <= type(uint32).max, "timeSystemWentUnderwater overflow");
            bool isUnderwater = (ls.timeSystemWentUnderwater != 0);
            bool wasUnderwater = (storedState.timeSystemWentUnderwater != 0);
            // timeSystemWentUnderwater should only change between 0 and non-0, never from one non-0 to another:
            require(isUnderwater != wasUnderwater, "Unexpected timeSystemWentUnderwater change");
            emit UnderwaterStatusChanged(isUnderwater);
        }

        uint priceToStore = ls.ethUsdPrice + HALF_BILLION;
        unchecked { priceToStore /= BILLION; }
        if (priceToStore != storedState.ethUsdPrice) {
            require(priceToStore <= type(uint80).max, "ethUsdPrice overflow");
            unchecked { emit PriceChanged(ls.ethUsdPriceTimestamp, priceToStore * BILLION); }
        }

        uint adjustmentToStore = ls.bidAskAdjustment + HALF_BILLION;
        unchecked { adjustmentToStore /= BILLION; }
        if (adjustmentToStore != storedState.bidAskAdjustment) {
            require(adjustmentToStore <= type(uint80).max, "bidAskAdjustment overflow");
            unchecked { emit BidAskAdjustmentChanged(adjustmentToStore * BILLION); }
        }

        (storedState.timeSystemWentUnderwater,
         storedState.ethUsdPriceTimestamp, storedState.ethUsdPrice,
         storedState.bidAskAdjustmentTimestamp, storedState.bidAskAdjustment) =
            (uint32(ls.timeSystemWentUnderwater),
             uint32(ls.ethUsdPriceTimestamp), uint80(priceToStore),
             uint32(ls.bidAskAdjustmentTimestamp), uint80(adjustmentToStore));
    }

    // ____________________ Public Oracle view functions ____________________

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime,) = checkForFreshOraclePrice(loadState());
    }

    // ____________________ Public informational view functions ____________________

    /**
     * @notice Checks the external oracle for a fresh ETH/USD price.  If it has one, we take it as the new USM system price
     * (and update `bidAskAdjustment` as described below); if no fresh oracle price is available, we stick with our existing
     * system price, `ls.ethUsdPrice`, which may have been nudged around by mint/burn operations since the last oracle update.
     *
     * Note that our definition of whether an oracle price is "fresh" (`updateTime > ls.ethUsdPriceTimestamp`) isn't as simple
     * as "whether it's changed since our last call."  Eg, we only consider a Uniswap TWAP price "fresh" when a new price
     * observation (trade) occurs, even though `price` may change without such an observation.  See the comment in
     * `Oracle.latestPrice()`.
     */
    function checkForFreshOraclePrice(LoadedState memory ls)
        public view returns (uint price, uint updateTime, uint adjustment)
    {
        (price, updateTime) = oracle.latestPrice();

        adjustment = ls.bidAskAdjustment;

        if (updateTime <= ls.ethUsdPriceTimestamp) {    // If oracle's price isn't fresher than our stored one, keep stored one
            (price, updateTime) = (ls.ethUsdPrice, ls.ethUsdPriceTimestamp);
        } else if (ls.ethUsdPrice != 0) {   // If the old price is 0, don't try to use it to adjust the bidAskAdjustment...
            /**
             * This is a bit subtle.  We want to update the mid stored price to the oracle's fresh value, while updating
             * bidAskAdjustment in such a way that the currently adjusted (more expensive than mid) side gets no cheaper/more
             * favorably priced for users.  Example:
             *
             * 1. storedPrice = $1,000, and bidAskAdjustment = 1.02.  So, our current ETH buy price is $1,020, and our current
             *    ETH sell price is $1,000 (mid).
             * 2. The oracle comes back with a fresh price (newer updateTime) of $990.
             * 3. The currently adjusted price is buy price (ie, adj > 1).  So, we want to:
             *    a) Update storedPrice (mid) to $990.
             *    b) Update bidAskAdj to ensure that buy price remains >= $1,020.
             * 4. We do this by upping bidAskAdj 1.02 -> 1.0303.  Then the new buy price will remain $990 * 1.0303 = $1,020.
             *    The sell price will remain the unadjusted mid: formerly $1,000, now $990.
             *
             * Because the bidAskAdjustment reverts to 1 in a few minutes, the new 3.03% buy premium is temporary: buy price
             * will revert to the $990 mid soon - unless the new mid is egregiously low, in which case buyers should push it
             * back up.  Eg, suppose the oracle gives us a glitchy price of $99.  Then new mid = $99, bidAskAdj = 10.303, buy
             * price = $1,020, and the buy price will rapidly drop towards $99; but as it does so, users are incentivized to
             * step in and buy, eventually pushing mid back up to the real-world ETH market price (eg $990).
             *
             * In cases like this, our bidAskAdj update has protected the system, by preventing users from getting any chance
             * to buy at the bogus $99 price.
             */
            if (adjustment > WAD) {
                // max(1, old buy price / new mid price):
                adjustment = WAD.wadMax(ls.ethUsdPrice.wadMulDivUp(adjustment, price));
            } else if (adjustment < WAD) {
                // min(1, old sell price / new mid price):
                adjustment = WAD.wadMin(ls.ethUsdPrice.wadMulDivDown(adjustment, price));
            }
        }
    }

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return pool ETH pool
     */
    function ethPool() public override view returns (uint pool) {
        pool = address(this).balance;
    }

    function fumTotalSupply() public override view returns (uint supply) {
        supply = fum.totalSupply();
    }

    /**
     * @notice The current bid/ask adjustment, equal to the stored value decayed over time towards its stable value, 1.  This
     * adjustment is intended as a measure of "how long-ETH recent user activity has been", so that we can slide price
     * accordingly: if recent activity was mostly long-ETH (`fund()` and `burn()`), raise FUM buy price/reduce USM sell price;
     * if recent activity was short-ETH (`defund()` and `mint()`), reduce FUM sell price/raise USM buy price.
     * @return adjustment The sliding-price bid/ask adjustment
     */
    function bidAskAdjustment() public override view returns (uint adjustment) {
        adjustment = loadState().bidAskAdjustment;      // Not just from storedState, b/c need to update it - see loadState()
    }

    function timeSystemWentUnderwater() public override view returns (uint timestamp) {
        timestamp = storedState.timeSystemWentUnderwater;
    }

    function isDuringPrefund() public override view returns (bool duringPrefund) {
        duringPrefund = block.timestamp < PREFUND_END_TIMESTAMP;
    }

    // ____________________ Public helper view functions (for functions above) ____________________

    /**
     * @return ls A `LoadedState` object packaging the system's current state: `ethUsdPrice`, `bidAskAdjustment`, etc (see
     * `storedState`), plus the ETH and USM balances.  `bidAskAdjustment` is also brought up to date, ie, decayed closer to 1
     * according to how much time has passed since it was stored: so if `bidAskAdjustment` was 2.0 five minutes ago, and
     * `BID_ASK_ADJUSTMENT_DECAY_PER_SECOND` corresponds to a half-life of 1 minute, `ls.bidAskAdjustment` is set to 1.03125
     * (see `bidAskAdjustment(storedTime, storedAdjustment, currentTime)`).
     */
    function loadState() public view returns (LoadedState memory ls) {
        ls.timeSystemWentUnderwater = storedState.timeSystemWentUnderwater;
        ls.ethUsdPriceTimestamp = storedState.ethUsdPriceTimestamp;
        ls.ethUsdPrice = storedState.ethUsdPrice * BILLION;     // Converting stored BILLION (1e9) format to WAD (1e18)

        // Bring bidAskAdjustment up to the present - it gravitates towards 1 over time, so the stored value is obsolete:
        ls.bidAskAdjustmentTimestamp = block.timestamp;
        ls.bidAskAdjustment = bidAskAdjustment(storedState.bidAskAdjustmentTimestamp,
                                               storedState.bidAskAdjustment * BILLION,
                                               block.timestamp);

        ls.ethPool = ethPool();
        ls.usmTotalSupply = totalSupply();
    }

    // ____________________ Public helper pure functions (for functions above) ____________________

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(uint ethUsdPrice, uint ethInPool, uint usmSupply, bool roundUp)
        public override pure returns (int buffer)
    {
        // Reverse the input upOrDown, since we're using it for usmToEth(), which will be *subtracted* from ethInPool below:
        uint usmValueInEth = usmToEth(ethUsdPrice, usmSupply, !roundUp);    // Iff rounding the buffer up, round usmValue down
        require(ethUsdPrice <= uint(type(int).max) && usmValueInEth <= uint(type(int).max), "ethBuffer overflow/underflow");
        buffer = int(ethInPool) - int(usmValueInEth);   // After the previous line, no over/underflow should be possible here
    }

    /**
     * @notice Calculate debt ratio for a given eth to USM price: ratio of the outstanding USM (amount of USM in total supply),
     * to the current ETH pool value in USD (ETH qty * ETH/USD price).
     * @return ratio Debt ratio (or 0 if there's currently 0 ETH in the pool/price = 0: these should never happen after launch)
     */
    function debtRatio(uint ethUsdPrice, uint ethInPool, uint usmSupply) public override pure returns (uint ratio) {
        uint ethPoolValueInUsd = ethInPool.wadMulDown(ethUsdPrice);
        ratio = (usmSupply == 0 ? 0 : (ethPoolValueInUsd == 0 ? type(uint).max : usmSupply.wadDivUp(ethPoolValueInUsd)));
    }

    /**
     * @notice Convert ETH amount to USM using a ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethUsdPrice, uint ethAmount, bool roundUp) public override pure returns (uint usmOut) {
        usmOut = ethAmount.wadMul(ethUsdPrice, roundUp);
    }

    /**
     * @notice Convert USM amount to ETH using a ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint ethUsdPrice, uint usmAmount, bool roundUp) public override pure returns (uint ethOut) {
        ethOut = usmAmount.wadDiv(ethUsdPrice, roundUp);
    }

    /**
     * @return price The ETH/USD price, adjusted by the `bidAskAdjustment` (if applicable) for the given buy/sell side.
     */
    function adjustedEthUsdPrice(IUSM.Side side, uint ethUsdPrice, uint adjustment) public override pure returns (uint price) {
        price = ethUsdPrice;

        // Apply the adjustment if (side == Buy and adj > 1), or (side == Sell and adj < 1):
        if (side == IUSM.Side.Buy ? (adjustment > WAD) : (adjustment < WAD)) {
            price = price.wadMul(adjustment, side == IUSM.Side.Buy);    // Round up iff side = buy
        }
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms): that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(IUSM.Side side, uint ethUsdPrice) public override pure returns (uint price) {
        price = usmToEth(ethUsdPrice, WAD, side == IUSM.Side.Buy);      // Round up iff side = buy
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms): that is, of the next unit, before the price starts rising.
     * @param usmEffectiveSupply should be either the actual current USM supply, or, when calculating the FUM *buy* price, the
     * return value of `usmSupplyForFumBuys()`.
     * @return price FUM price in ETH terms
     */
    function fumPrice(IUSM.Side side, uint ethUsdPrice, uint ethInPool, uint usmEffectiveSupply, uint fumSupply, bool prefund)
        public override pure returns (uint price)
    {
        if (prefund) {
            price = PREFUND_FUM_PRICE_IN_ETH;   // We're in the prefund period, so the price is just the prefund's "prix fixe"
        } else {
            // Using usmEffectiveSupply here, rather than just the raw actual supply, has the effect of bumping the FUM price
            // up to the minFumBuyPrice when needed (ie, when debt ratio > MAX_DEBT_RATIO):
            bool roundUp = (side == IUSM.Side.Buy);
            int buffer = ethBuffer(ethUsdPrice, ethInPool, usmEffectiveSupply, roundUp);
            price = (buffer <= 0 ? 0 : uint(buffer).wadDiv(fumSupply, roundUp));
        }
    }

    /**
     * @return timeSystemWentUnderwater_ The time at which we first detected the system was underwater (debt ratio >
     * `MAX_DEBT_RATIO`), based on the current oracle price and pool ETH and USM; or 0 if we're not currently underwater.
     * @return usmSupplyForFumBuys The current supply of USM *for purposes of calculating the FUM buy price,* and therefore
     * for `fumFromFund()`.  The "supply for FUM buys" is the *lesser* of the actual current USM supply, and the USM amount
     * that would make debt ratio = `MAX_DEBT_RATIO`.  Example:
     *
     * 1. Suppose the system currently contains 50 ETH at price $1,000 (total pool value: $50,000), with an actual USM supply
     *    of 30,000 USM.  Then debt ratio = 30,000 / $50,000 = 60%: < MAX 80%, so `usmSupplyForFumBuys` = 30,000.
     * 2. Now suppose ETH/USD halves to $500.  Then pool value halves to $25,000, and debt ratio doubles to 120%.  Now
     *    `usmSupplyForFumBuys` instead = 20,000: the USM quantity at which debt ratio would equal 80% (20,000 / $25,000).
     *    (Call this the "80% supply".)
     * 3. ...Except, we also gradually increase the supply over time while we remain underwater.  This has the effect of
     *    *reducing* the FUM buy price inferred from that supply (higher JacobUSM supply -> smaller buffer -> lower FUM price).
     *    The math we use gradually increases the supply from its initial "80% supply" value, where debt ratio =
     *    `MAX_DEBT_RATIO` (20,000 above), to a theoretical maximum "100% supply" value, where debt ratio = 100% (in the $500
     *    example above, this would be 25,000).  (Or the actual supply, whichever is lower: we never increase
     *    `usmSupplyForFumBuys` above `usmActualSupply`.)  The climb from the initial 80% supply (20,000) to the 100% supply
     *    (25,000) is at a rate that brings it "halfway closer per `minFumBuyPrice` half-life (eg, 1 day)": so three days after
     *    going underwater, the supply returned will be 25,000 - 0.5**3 * (25,000 - 20,000) = 24,375.
     */
    function checkIfUnderwater(uint usmActualSupply, uint ethPool_, uint ethUsdPrice, uint oldTimeUnderwater, uint currentTime)
        public override pure returns (uint timeSystemWentUnderwater_, uint usmSupplyForFumBuys, uint debtRatio_)
    {
        debtRatio_ = debtRatio(ethUsdPrice, ethPool_, usmActualSupply);
        if (debtRatio_ <= MAX_DEBT_RATIO) {            // We're not underwater, so leave timeSystemWentUnderwater_ as 0
            usmSupplyForFumBuys = usmActualSupply;     // When not underwater, USM supply for FUM buys is just actual supply
        } else {                                       // We're underwater
            // Set timeSystemWentUnderwater_ to currentTime, if it wasn't already set:
            timeSystemWentUnderwater_ = (oldTimeUnderwater != 0 ? oldTimeUnderwater : currentTime);

            // Calculate usmSupplyForFumBuys:
            uint maxEffectiveDebtRatio = debtRatio_.wadMin(WAD);    // min(actual debt ratio, 100%)
            uint decayFactor = MIN_FUM_BUY_PRICE_DECAY_PER_SECOND.wadPowInt(currentTime - timeSystemWentUnderwater_);
            uint effectiveDebtRatio = maxEffectiveDebtRatio - decayFactor.wadMulUp(maxEffectiveDebtRatio - MAX_DEBT_RATIO);
            usmSupplyForFumBuys = effectiveDebtRatio.wadMulDown(ethPool_.wadMulDown(ethUsdPrice));
        }
    }

    /**
     * @notice Returns the given stored `bidAskAdjustment` value, updated (decayed towards 1) to the current time.
     */
    function bidAskAdjustment(uint storedTime, uint storedAdjustment, uint currentTime) public pure returns (uint adjustment) {
        uint secsSinceStored = currentTime - storedTime;
        // ZERO_OUT_PERIOD here is important, so a long gap between ops doesn't waste a lot of gas calculating the ~0 decay:
        uint decayFactor = (secsSinceStored >= BID_ASK_ADJUSTMENT_ZERO_OUT_PERIOD ? 0 :
                            BID_ASK_ADJUSTMENT_DECAY_PER_SECOND.wadPowInt(secsSinceStored));
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        adjustment = WAD + storedAdjustment.wadMulDown(decayFactor) - decayFactor;
    }

    /**
     * @notice How much USM a minter currently gets back for `ethIn` ETH, accounting for `bidAskAdjustment` and sliding prices.
     * @param ethIn The amount of ETH passed to `mint()`
     * @return usmOut The amount of USM to receive in exchange
     */
    function usmFromMint(LoadedState memory ls, uint ethIn)
        public pure returns (uint usmOut, uint adjShrinkFactor)
    {
        // The USM buy price we pay, in ETH terms, "slides up" as we buy, proportional to the ETH in the pool: if the pool
        // starts with 100 ETH, and ethIn = 5, so we're increasing it to 105, then our USM/ETH buy price increases smoothly by
        // 5% during the mint operation.  (Buying USM with ETH is economically equivalent to selling ETH for USD: so this is
        // equivalent to saying that the ETH/USD price used to price our USM *decreases* smoothly by 5% during the operation.)
        // Of that 5%, "half" (in log space) is the ETH/USD *mid* price dropping, and the other half is the bidAskAdjustment
        // (ETH sell price discount) dropping.
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Sell, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint usmBuyPrice0 = usmPrice(IUSM.Side.Buy, adjustedEthUsdPrice0);      // Minting USM = buying USM = selling ETH
        uint ethPool1 = ls.ethPool + ethIn;

        uint oneOverEthGrowthFactor = ls.ethPool.wadDivDown(ethPool1);
        adjShrinkFactor = oneOverEthGrowthFactor.wadSqrtDown();

        // In theory, calculating the total amount of USM minted involves summing an integral over 1 / usmBuyPrice, which gives
        // the following simple logarithm:
        //int log = ethPool1.wadDivDown(ls.ethPool).wadLog();                   // 2a) Most exact: ~4k more gas
        //require(log >= 0, "log underflow");
        //usmOut = ls.ethPool.wadMulDivDown(uint(log), usmBuyPrice0);

        // But in practice, we can save some gas by approximating the log integral above as follows: take the geometric average
        // of the starting and ending usmBuyPrices, and just apply that average price to the entire ethIn passed in.
        uint usmBuyPriceAvg = usmBuyPrice0.wadDivUp(adjShrinkFactor);
        usmOut = ethIn.wadDivDown(usmBuyPriceAvg);
    }

    /**
     * @notice How much ETH a burner currently gets from burning `usmIn` USM, accounting for `bidAskAdjustment` and sliding
     * prices.
     * @param usmIn The amount of USM passed to `burn()`
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromBurn(LoadedState memory ls, uint usmIn)
        public pure returns (uint ethOut, uint adjGrowthFactor)
    {
        // Burn USM at a sliding-down USM price (ie, a sliding-up ETH price).  This is just the mirror image of the math in
        // usmFromMint() above, but because we're calculating output ETH from input USM rather than the other way around, we
        // end up with an exponent (exponent.wadExpDown() below, aka e**exponent) rather than a logarithm.
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Buy, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint usmSellPrice0 = usmPrice(IUSM.Side.Sell, adjustedEthUsdPrice0);    // Burning USM = selling USM = buying ETH

        // The USM sell price is capped by the ETH pool value per USM outstanding.  In other words, when the system is
        // underwater (debt ratio > 100%), burners "take a haircut" - burning USM yields less than $1 of ETH per USM burned:
        usmSellPrice0 = usmSellPrice0.wadMin(ls.ethPool.wadDivDown(ls.usmTotalSupply));

        // The exact integral - calculating the amount of ETH yielded by burning the USM at our sliding-down USM price:
        uint exponent = usmIn.wadMulDivDown(usmSellPrice0, ls.ethPool);
        uint ethPool1 = ls.ethPool.wadDivUp(exponent.wadExpDown());
        ethOut = ls.ethPool - ethPool1;

        // In this case we back out the adjGrowthFactor (change in mid price and bidAskAdj) from the change in the ETH pool:
        adjGrowthFactor = ls.ethPool.wadDivUp(ethPool1).wadSqrtUp();
    }

    /**
     * @notice How much FUM a funder currently gets back for `ethIn` ETH, accounting for `bidAskAdjustment` and sliding prices.
     * Note that we expect `ls.usmTotalSupply` of the LoadedState passed in to not necessarily be the actual current total USM
     * supply, but the *effective* USM supply for purposes of this operation - which can be a lower number, artificially
     * increasing the FUM price.  This is our "minFumBuyPrice" logic, used to prevent FUM buyers from paying tiny or negative
     * prices when the system is underwater or near it.
     * @param ethIn The amount of ETH passed to `fund()`
     * @return fumOut The amount of FUM to receive in exchange
     */
    function fumFromFund(LoadedState memory ls, uint fumSupply, uint ethIn, uint debtRatio_, bool prefund)
        public pure returns (uint fumOut, uint adjGrowthFactor)
    {
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Buy, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint fumBuyPrice0 = fumPrice(IUSM.Side.Buy, adjustedEthUsdPrice0, ls.ethPool, ls.usmTotalSupply, fumSupply, prefund);
        if (prefund) {
            // We're in the prefund period, so no fees - fumOut is just ethIn divided by the fixed prefund FUM price:
            adjGrowthFactor = WAD;
            fumOut = ethIn.wadDivDown(fumBuyPrice0);
        } else {
            // Create FUM at a sliding-up FUM price.  We follow the same broad strategy as in usmFromMint(): the effective ETH
            // price increases smoothly during the fund() operation, proportionally to the fraction by which the ETH pool
            // grows.  But there are a couple of extra nuances in the FUM case:
            //
            // 1. FUM is "leveraged"/"higher-delta" ETH, so minting 1 ETH worth of FUM should move the price by more than
            //    minting 1 ETH worth of USM does.  (More by a "net FUM delta" factor.)
            // 2. The theoretical FUM price is based on the ETH buffer (excess ETH beyond what's needed to cover the
            //    outstanding USM), which is itself affected by/during this fund operation...
            //
            // The code below uses a "reasonable approximation" to deal with those complications.  See also the discussion in:
            // https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f

            { // Scope for adjGrowthFactor, to avoid the dreaded "stack too deep" error.  Thanks Uniswap v2 for the trick!
                // 1. Start by calculating the "net FUM delta" described above - the factor by which this operation will move
                // the ETH price more than a simple mint() operation would.  Calculating the pure, fluctuating theoretical
                // delta is a mess: we calculate the initial delta and pretend it stays fixed thereafter.  The theoretical
                // delta *decreases* during a fund() call (as the pool grows, the ETH/USD price increases, and FUM becomes less
                // leveraged), so holding it fixed at its initial value is "pessimistic", like we want - ensures we charge more
                // fees than the theoretical amount, not less.
                uint effectiveDebtRatio0 = debtRatio_.wadMin(MAX_DEBT_RATIO);
                uint netFumDelta = effectiveDebtRatio0.wadDivUp(WAD - effectiveDebtRatio0);

                // 2. Given the delta, we can calculate the adjGrowthFactor (price impact): for mint() (delta 1), the factor
                // was poolChangeFactor**(1 / 2); now instead we use poolChangeFactor**(netFumDelta / 2).
                uint ethPool1 = ls.ethPool + ethIn;
                adjGrowthFactor = ethPool1.wadDivUp(ls.ethPool).wadPowUp(netFumDelta / 2);
            }

            // 3. Here we use the same simplifying trick as usmFromMint() above: we pretend our entire FUM purchase is done at
            // a single fixed price.  For that fixed FUM price, we again use the trick of taking the geometric average of the
            // starting and ending FUM buy prices, which we can calculate exactly now that we know the ending ETH pool quantity
            // (from ethIn) and the ending adjusted ETH/USD price (from the adjGrowthFactor calculated above).  This geometric
            // average isn't as accurate an approximation of the theoretical integral here as it was for usmFromMint(), since
            // the FUM buy price follows a less predictable curve than the USM buy price, but it's close enough for our
            // purposes: we mostly just want to charge funders a positive fee, that increases as a % of ethIn as ethIn gets
            // larger ("larger trades pay superlinearly larger fees").
            uint adjustedEthUsdPrice1 = adjustedEthUsdPrice0.wadMulUp(adjGrowthFactor.wadSquaredUp());
            uint fumBuyPrice1 = fumPrice(IUSM.Side.Buy, adjustedEthUsdPrice1, ls.ethPool, ls.usmTotalSupply, fumSupply,
                                         prefund);
            uint avgFumBuyPrice = fumBuyPrice0.wadMulUp(fumBuyPrice1).wadSqrtUp();      // Taking the geometric avg
            fumOut = ethIn.wadDivDown(avgFumBuyPrice);
        }
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustment and sliding prices.
     * @param fumIn The amount of FUM passed to `defund()`
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromDefund(LoadedState memory ls, uint fumSupply, uint fumIn)
        public pure returns (uint ethOut, uint adjShrinkFactor)
    {
        // Burn FUM at a sliding-down FUM price.  Our approximation technique here resembles the one in fumFromFund() above,
        // but we need to be even more clever this time...

        // 1. Calculating the initial FUM sell price we start from is no problem:
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Sell, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint fumSellPrice0 = fumPrice(IUSM.Side.Sell, adjustedEthUsdPrice0, ls.ethPool, ls.usmTotalSupply, fumSupply, false);

        { // Scope for adjShrinkFactor, to avoid the dreaded "stack too deep" error.  Thanks Uniswap v2 for the trick!
            // 2. Now we want a "pessimistic" lower bound on the ending ETH pool qty.  We can get this by supposing the entire
            // burn happened at our initial fumSellPrice0: this is "optimistic" in terms of how much ETH we'd get back, but
            // "pessimistic" in the sense we want - how much ETH would be left in the pool:
            uint lowerBoundEthQty1 = ls.ethPool - fumIn.wadMulUp(fumSellPrice0);
            uint lowerBoundEthShrinkFactor1 = lowerBoundEthQty1.wadDivDown(ls.ethPool);

            // 3. From this "pessimistic" lower bound on the ending ETH qty, and a similarly pessimistic netFumDelta value of 4
            // (the netFumDelta when debt ratio is at the highest value it can end at here, MAX_DEBT_RATIO), we can calculate a
            // "pessimistic" lower bound on our ending adjustedEthUsdPrice, ie, overstating how large an impact our burn could
            // have on the ETH/USD price used to calculate our FUM sell price:
            uint adjustedEthUsdPrice1 = adjustedEthUsdPrice0.wadMulDown(lowerBoundEthShrinkFactor1.wadPowDown(FOUR_WAD));

            // 4. From adjustedEthUsdPrice1, we can calculate a pessimistic (upper-bound) debtRatio2 we'll end up at after the
            // defund operation, and from debtRatio2, a pessimistic (upper-bound) netFumDelta2 we can hold fixed during the
            // calculation:
            uint debtRatio1 = debtRatio(adjustedEthUsdPrice1, lowerBoundEthQty1, ls.usmTotalSupply);
            uint debtRatio2 = debtRatio1.wadMin(MAX_DEBT_RATIO);    // defund() fails anyway if dr ends > MAX, so cap it at MAX
            uint netFumDelta2 = WAD.wadDivUp(WAD - debtRatio2) - WAD;

            // 5. Combining lowerBoundEthShrinkFactor1 and netFumDelta2 gives us our final, pessimistic adjShrinkFactor, from
            // our standard formula adjChangeFactor = ethChangeFactor**(netFumDelta / 2):
            adjShrinkFactor = lowerBoundEthShrinkFactor1.wadPowDown(netFumDelta2 / 2);
        }

        // 6. And adjShrinkFactor tells us the adjustedEthUsdPrice2 we'll end the operation at, from which we can also
        // calculate the instantaneous FUM sell price we'll end the operation at, just as we calculated our ending fumBuyPrice1
        // in fumFromFund():
        uint adjustedEthUsdPrice2 = adjustedEthUsdPrice0.wadMulDown(adjShrinkFactor.wadSquaredDown());
        uint fumSellPrice2 = fumPrice(IUSM.Side.Sell, adjustedEthUsdPrice2, ls.ethPool, ls.usmTotalSupply, fumSupply, false);

        // 7. We now know the starting fumSellPrice0, and the ending fumSellPrice2.  We want to combine these to get a single
        // avgFumSellPrice we can use for the entire defund operation, which will trivially give us ethOut.  But taking the
        // geometric average again, as we did in usmFromMint() and fumFromFund(), is dicey in the defund() case: fumSellPrice2
        // could be arbitrarily close to 0, which would make avgFumSellPrice arbitrarily close to 0, which would have the
        // highly perverse result that a *larger* fumIn returns strictly *less* ETH!  What alternative to geometric average
        // gives the best results here is a complicated problem, but one simple option that avoids the avgFumSellPrice = 0 flaw
        // is to just take the arithmetic average instead, (fumSellPrice0 + fumSellPrice2) / 2:
        uint avgFumSellPrice = (fumSellPrice0 + fumSellPrice2) / 2;
        ethOut = fumIn.wadMulDown(avgFumSellPrice);
    }
}
