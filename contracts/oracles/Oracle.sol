// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

interface UniswapAnchoredView {
    function price(string calldata symbol) external view returns (uint);
}

/**
 * @title Oracle
 * @author Jacob Eliosoff (@jacob-eliosoff)
 */
contract Oracle {
    using SafeMath for uint;

    uint private constant NUM_ORACLES_TO_MEDIAN = 3;

    // The source oracles may have different decimalShifts from us, so we'll need to shift them:
    uint private constant CHAINLINK_SHIFT_FACTOR = 10 ** 10;            // Since Chainlink oracle has 8 dec places, and we want 18
    uint private constant COMPOUND_SHIFT_FACTOR = 10 ** 12;             // Compound has 6, and we want 18
    uint private constant UNISWAP_ETH_USDT_SCALE_FACTOR = 10 ** 30;     // Uniswap ETH/USDT has -12, and we want 18
    uint private constant UNISWAP_USDC_ETH_SCALE_FACTOR = 10 ** 6;      // Uniswap USDC/ETH has 12, and we want 18
    uint private constant UNISWAP_DAI_ETH_SCALE_FACTOR = 10 ** 18;      // Uniswap DAI/ETH has 0, and we want 18

    struct UniswapPriceablePair {
        IUniswapV2Pair pair;
        bool tokensInReverseOrder;
        uint scaleFactor;
    }

    AggregatorV3Interface public chainlinkOracle;
    UniswapAnchoredView public compoundOracle;
    UniswapPriceablePair public uniswapEthUsdtPair;
    UniswapPriceablePair public uniswapUsdcEthPair;
    UniswapPriceablePair public uniswapDaiEthPair;

    constructor(address chainlinkOracle_, address compoundOracle_,
                address uniswapEthUsdtPair_, bool uniswapEthUsdtPairInReverseOrder_,
                address uniswapUsdcEthPair_, bool uniswapUsdcEthPairInReverseOrder_,
                address uniswapDaiEthPair_, bool uniswapDaiEthPairInReverseOrder_) public
    {
        chainlinkOracle = AggregatorV3Interface(chainlinkOracle_);
        compoundOracle = UniswapAnchoredView(compoundOracle_);
        uniswapEthUsdtPair = UniswapPriceablePair(IUniswapV2Pair(uniswapEthUsdtPair_), uniswapEthUsdtPairInReverseOrder_,
                                                  UNISWAP_ETH_USDT_SCALE_FACTOR);
        uniswapUsdcEthPair = UniswapPriceablePair(IUniswapV2Pair(uniswapUsdcEthPair_), uniswapUsdcEthPairInReverseOrder_,
                                                  UNISWAP_USDC_ETH_SCALE_FACTOR);
        uniswapDaiEthPair = UniswapPriceablePair(IUniswapV2Pair(uniswapDaiEthPair_), uniswapDaiEthPairInReverseOrder_,
                                                  UNISWAP_DAI_ETH_SCALE_FACTOR);
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function oraclePrice() public virtual view returns (uint price) {
        price = latestMedianPrice();//.wadDiv(10 ** oracleDecimalShift);
    }

    function latestMedianPrice() internal view returns (uint price) {
        // For maximal gas efficiency...
        price = median([latestChainlinkPrice(), latestCompoundPrice(), latestUniswapMedianPrice()]);
    }

    function latestChainlinkPrice() internal view returns (uint price) {
        (, int rawPrice,,,) = chainlinkOracle.latestRoundData();
        price = uint(rawPrice).mul(CHAINLINK_SHIFT_FACTOR); // TODO: Cast safely
    }

    function latestCompoundPrice() internal view returns (uint price) {
        price = compoundOracle.price("ETH").mul(COMPOUND_SHIFT_FACTOR);
    }

    function latestUniswapMedianPrice() internal view returns (uint price) {
        price = median([latestUniswapPairPrice(uniswapEthUsdtPair),
                        latestUniswapPairPrice(uniswapUsdcEthPair),
                        latestUniswapPairPrice(uniswapDaiEthPair)]);
    }

    function latestUniswapPairPrice(UniswapPriceablePair memory pair)
        internal view returns (uint price)
    {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint112 reserve0, uint112 reserve1,) = pair.pair.getReserves();
        (uint112 reserveA, uint112 reserveB) = pair.tokensInReverseOrder ? (reserve1, reserve0) : (reserve0, reserve1);
        price = (uint(reserveB)).mul(pair.scaleFactor).div(uint(reserveA));
    }

    function median(uint[NUM_ORACLES_TO_MEDIAN] memory xs)
        public pure returns (uint)
    {
        require(xs.length == 3, "Only 3 supported for now");

        uint a = xs[0];
        uint b = xs[1];
        uint c = xs[2];
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}
