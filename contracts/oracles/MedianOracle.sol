// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ChainlinkOracle.sol";
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
        view returns (uint price)
    {
        price = median(ChainlinkOracle.latestPrice(),
                       UniswapV3TWAPOracle.latestPrice(),
                       UniswapV3TWAPOracle2.latestPrice());
    }

    function latestChainlinkPrice() public view returns (uint price) {
        price = ChainlinkOracle.latestPrice();
    }

    function latestUniswapV3TWAPPrice1() public view returns (uint price) {
        price = UniswapV3TWAPOracle.latestPrice();
    }

    function latestUniswapV3TWAPPrice2() public view returns (uint price) {
        price = UniswapV3TWAPOracle2.latestPrice();
    }

    /**
     * @notice Currently only supports three inputs
     * @return m the median of the three values passed in
     */
    function median(uint a, uint b, uint c)
        public pure returns (uint m)
    {
        m = ((c > a) == (a > b) ? a : ((a > b) == (b > c) ? b : c));
    }
}
