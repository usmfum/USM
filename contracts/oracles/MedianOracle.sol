// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./UniswapV2TWAPOracle.sol";

/**
 * We make MedianOracle *inherit* its median-component oracles (eg, ChainlinkOracle), rather than hold them as state variables
 * like any sane person would, because this significantly reduces the number of (gas-pricey) external contract calls.
 * Eg, this contract calling ChainlinkOracle.latestPrice() on itself is significantly cheaper than calling
 * chainlinkOracle.latestPrice() on a chainlinkOracle var (contract).
 */
contract MedianOracle is ChainlinkOracle, CompoundOpenOracle, UniswapV2TWAPOracle {

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        CompoundUniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapTokenToUse, int uniswapTokenDecimals
    )
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        UniswapV2TWAPOracle(uniswapPair, uniswapTokenToUse, uniswapTokenDecimals) {}

    function latestPrice() public virtual override(ChainlinkOracle, CompoundOpenOracle, UniswapV2TWAPOracle)
        view returns (uint price, uint updateTime)
    {
        (uint chainlinkPrice, uint chainlinkUpdateTime) = ChainlinkOracle.latestPrice();
        (uint compoundPrice, uint compoundUpdateTime) = CompoundOpenOracle.latestPrice();
        (uint uniswapPrice, uint uniswapUpdateTime) = UniswapV2TWAPOracle.latestPrice();
        (price, updateTime) = medianPriceAndUpdateTime(chainlinkPrice, chainlinkUpdateTime,
                                                       compoundPrice, compoundUpdateTime,
                                                       uniswapPrice, uniswapUpdateTime);
    }

    function latestChainlinkPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = ChainlinkOracle.latestPrice();
    }

    function latestCompoundPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = CompoundOpenOracle.latestPrice();
    }

    function latestUniswapTWAPPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = UniswapV2TWAPOracle.latestPrice();
    }

    function refreshPrice() public virtual override(Oracle, CompoundOpenOracle, UniswapV2TWAPOracle)
        returns (uint price, uint updateTime)
    {
        // Not ideal to call latestPrice() on one of these and refreshPrice() on two...  But it works, and inheriting them like
        // this saves significant gas:
        (uint chainlinkPrice, uint chainlinkUpdateTime) = ChainlinkOracle.latestPrice();
        (uint compoundPrice, uint compoundUpdateTime) = CompoundOpenOracle.refreshPrice();      // Note: refreshPrice()
        (uint uniswapPrice, uint uniswapUpdateTime) = UniswapV2TWAPOracle.refreshPrice();       // Note: refreshPrice()
        (price, updateTime) = medianPriceAndUpdateTime(chainlinkPrice, chainlinkUpdateTime,
                                                       compoundPrice, compoundUpdateTime,
                                                       uniswapPrice, uniswapUpdateTime);
    }

    /**
     * @notice Currently only supports three inputs
     * @return price the median price of the three passed in
     * @return updateTime the updateTime corresponding to the median price.  Not the median of the three updateTimes!
     */
    function medianPriceAndUpdateTime(uint p1, uint t1, uint p2, uint t2, uint p3, uint t3)
        public pure returns (uint price, uint updateTime)
    {
        bool p1gtp2 = p1 > p2;
        bool p2gtp3 = p2 > p3;
        bool p3gtp1 = p3 > p1;

        (price, updateTime) = (p3gtp1 == p1gtp2 ? (p1, t1) : (p1gtp2 == p2gtp3 ? (p2, t2) : (p3, t3)));
    }
}
