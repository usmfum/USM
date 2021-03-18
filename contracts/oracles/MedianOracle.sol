// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./OurUniswapV2TWAPOracle.sol";

/**
 * We make MedianOracle *inherit* its median-component oracles (eg, ChainlinkOracle), rather than hold them as state variables
 * like any sane person would, because this significantly reduces the number of (gas-pricey) external contract calls.
 * Eg, this contract calling ChainlinkOracle.latestPrice() on itself is significantly cheaper than calling
 * chainlinkOracle.latestPrice() on a chainlinkOracle var (contract).
 */
contract MedianOracle is ChainlinkOracle, CompoundOpenOracle, OurUniswapV2TWAPOracle {

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapTokenToUse, int uniswapTokenDecimals
    )
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        OurUniswapV2TWAPOracle(uniswapPair, uniswapTokenToUse, uniswapTokenDecimals) {}

    function latestPrice() public virtual override(ChainlinkOracle, CompoundOpenOracle, OurUniswapV2TWAPOracle)
        view returns (uint price, uint updateTime)
    {
        (price, updateTime) = latestMedianOraclePrice();
    }

    function latestMedianOraclePrice() public view returns (uint price, uint updateTime) {
        (uint chainlinkPrice, uint chainlinkUpdateTime) = ChainlinkOracle.latestPrice();
        (uint compoundPrice, uint compoundUpdateTime) = CompoundOpenOracle.latestPrice();
        (uint uniswapPrice, uint uniswapUpdateTime) = OurUniswapV2TWAPOracle.latestPrice();
        uint index = medianIndex(chainlinkPrice, compoundPrice, uniswapPrice);
        (price, updateTime) = (index == 0 ? (chainlinkPrice, chainlinkUpdateTime) :
                                            (index == 1 ? (compoundPrice, compoundUpdateTime) :
                                                          (uniswapPrice, uniswapUpdateTime)));
    }

    function refreshPrice() public virtual override(Oracle, CompoundOpenOracle, OurUniswapV2TWAPOracle)
        returns (uint price, uint updateTime)
    {
        // Not ideal to call latestPrice() on one of these and refreshPrice() on two...  But it works, and inheriting them like
        // this saves significant gas:
        (uint chainlinkPrice, uint chainlinkUpdateTime) = ChainlinkOracle.latestPrice();
        (uint compoundPrice, uint compoundUpdateTime) = CompoundOpenOracle.refreshPrice();      // Note: refreshPrice()
        (uint uniswapPrice, uint uniswapUpdateTime) = OurUniswapV2TWAPOracle.refreshPrice();    // Note: refreshPrice()
        uint index = medianIndex(chainlinkPrice, compoundPrice, uniswapPrice);
        (price, updateTime) = (index == 0 ? (chainlinkPrice, chainlinkUpdateTime) :
                                            (index == 1 ? (compoundPrice, compoundUpdateTime) :
                                                          (uniswapPrice, uniswapUpdateTime)));
    }

    /**
     * @notice Currently only supports three inputs
     * @return index (0/1/2) of the median value
     */
    function medianIndex(uint a, uint b, uint c)
        public pure returns (uint index)
    {
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        index = (ca == ab ? 0 : (ab == bc ? 1 : 2));
    }
}
