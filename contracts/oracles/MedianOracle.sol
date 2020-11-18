// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Oracle.sol";
import "./ChainlinkOracle.sol";
import "./CompoundOpenOracle.sol";
import "./UniswapMedianOracle.sol";
import "./Median.sol";

contract MedianOracle is Oracle, ChainlinkOracle, CompoundOpenOracle, UniswapMedianOracle {
    using SafeMath for uint;

    uint private constant NUM_UNISWAP_PAIRS = 3;

    constructor(address chainlinkAggregator, address compoundView,
                address[NUM_UNISWAP_PAIRS] memory uniswapPairs, bool[NUM_UNISWAP_PAIRS] memory uniswapTokensInReverseOrder,
                uint[NUM_UNISWAP_PAIRS] memory uniswapScaleFactors) public
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        UniswapMedianOracle(uniswapPairs, uniswapTokensInReverseOrder, uniswapScaleFactors) {}

    function latestPrice() public override(Oracle, ChainlinkOracle, CompoundOpenOracle, UniswapMedianOracle)
        view returns (uint price)
    {
        price = Median.median([latestChainlinkPrice(),
                               latestCompoundPrice(),
                               latestUniswapMedianPrice()]);
    }
}
