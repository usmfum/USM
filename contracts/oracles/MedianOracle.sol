// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./UniswapV3TWAPOracle.sol";
import "./UniswapV3TWAPOracle2.sol";

/**
 * We make MedianOracle *inherit* its median-component oracles (eg, ChainlinkOracle), rather than hold them as state variables
 * like any sane person would, because this significantly reduces the number of (gas-pricey) external contract calls.
 * Eg, this contract calling ChainlinkOracle.latestPrice() on itself is significantly cheaper than calling
 * chainlinkOracle.latestPrice() on a chainlinkOracle var (contract).
 */
contract MedianOracle is ChainlinkOracle, UniswapV3TWAPOracle, UniswapV3TWAPOracle2 {

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        IUniswapV3Pool uniswapPool1, uint uniswapTokenToPrice1, int uniswapDecimals1,
        IUniswapV3Pool uniswapPool2, uint uniswapTokenToPrice2, int uniswapDecimals2
    )
        ChainlinkOracle(chainlinkAggregator)
        UniswapV3TWAPOracle(uniswapPool1, uniswapTokenToPrice1, uniswapDecimals1)
        UniswapV3TWAPOracle2(uniswapPool2, uniswapTokenToPrice2, uniswapDecimals2) {}

    function latestPrice() public virtual override(ChainlinkOracle, UniswapV3TWAPOracle, UniswapV3TWAPOracle2)
        view returns (uint price, uint updateTime)
    {
        (uint chainlinkPrice, uint chainlinkUpdateTime) = ChainlinkOracle.latestPrice();
        (uint uniswapPrice1, uint uniswapUpdateTime1) = UniswapV3TWAPOracle.latestPrice();
        (uint uniswapPrice2, uint uniswapUpdateTime2) = UniswapV3TWAPOracle2.latestPrice();
        (price, updateTime) = medianPriceAndUpdateTime(chainlinkPrice, chainlinkUpdateTime,
                                                       uniswapPrice1, uniswapUpdateTime1,
                                                       uniswapPrice2, uniswapUpdateTime2);
    }

    function latestChainlinkPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = ChainlinkOracle.latestPrice();
    }

    function latestUniswapV3TWAPPrice1() public view returns (uint price, uint updateTime) {
        (price, updateTime) = UniswapV3TWAPOracle.latestPrice();
    }

    function latestUniswapV3TWAPPrice2() public view returns (uint price, uint updateTime) {
        (price, updateTime) = UniswapV3TWAPOracle2.latestPrice();
    }

    function refreshPrice() public virtual override(Oracle)
        returns (uint price, uint updateTime)
    {
        (price, updateTime) = latestPrice();
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
