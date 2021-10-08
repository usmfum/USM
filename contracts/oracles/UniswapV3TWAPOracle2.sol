// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
//import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "./uniswap/v3-periphery/OracleLibrary.sol";
import "./Oracle.sol";

/**
 * This is all just a copy of UniswapV3TWAPOracle, so that MedianOracle can inherit both of them without conflicts.  It would
 * of course be cleaner to make MedianOracle hold them as member variables, but that would cost more gas due to external calls.
 */
contract UniswapV3TWAPOracle2 is Oracle {
    uint32 public constant UNISWAP_TWAP_PERIOD_2 = 10 minutes;

    uint private constant WAD = 1e18;

    IUniswapV3Pool public immutable uniswapV3Pool2;
    uint public immutable uniswapTokenToPrice2;
    uint128 public immutable uniswapScaleFactor2;

    constructor(IUniswapV3Pool pool, uint tokenToPrice, int decimalPlaces) {
        uniswapV3Pool2 = pool;
        require(tokenToPrice == 0 || tokenToPrice == 1, "tokenToPrice not 0 or 1");
        uniswapTokenToPrice2 = tokenToPrice;
        uniswapScaleFactor2 = uint128(decimalPlaces >= 0 ?
            WAD / 10 ** uint(decimalPlaces) :
            WAD * 10 ** uint(-decimalPlaces));
    }

    function latestPrice() public virtual override view returns (uint price) {
        int24 twapTick = OracleLibrary.consult(address(uniswapV3Pool2), UNISWAP_TWAP_PERIOD_2);
        price = uniswapTokenToPrice2 == 1 ?
            OracleLibrary.getQuoteAtTick(twapTick, uniswapScaleFactor2, uniswapV3Pool2.token1(), uniswapV3Pool2.token0()) :
            OracleLibrary.getQuoteAtTick(twapTick, uniswapScaleFactor2, uniswapV3Pool2.token0(), uniswapV3Pool2.token1());
    }
}
