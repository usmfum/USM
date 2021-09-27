// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "./Oracle.sol";
//import "hardhat/console.sol";

contract UniswapV3TWAPOracle is Oracle {
    uint32 public constant UNISWAP_TWAP_PERIOD = 10 minutes;

    uint private constant WAD = 1e18;

    IUniswapV3Pool public immutable uniswapV3Pool;
    uint public immutable uniswapTokenToPrice;      // See constructor comment below.
    uint128 public immutable uniswapScaleFactor;

    /**
     * @notice Example pools to pass in:
     * USDC/ETH (0.05%): 0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640, 1, -12
     * ETH/USDT (0.05%): 0x11b815efb8f581194ae79006d24e0d814b7697f6, 0, -12
     * @param tokenToPrice Which token we're pricing (0 or 1) relative to the other.  Eg, for the USDC/ETH pool (token0 = USDC,
     * token1 = ETH), we want the price of ETH in terms of USDC, not vice versa: so we should pass in `tokenToPrice == 1'.
     * @param decimalPlaces How many decimal places are already included in the numbers Uniswap returns.  So,
     * `decimalPlaces = 3` means when Uniswap returns 12345, it actually represents 12.345 (ie, the last three digits were the
     * decimal part). `decimalPlaces = -3` means when Uniswap returns 12345, it actually represents 12,345,000.
     */
    constructor(IUniswapV3Pool pool, uint tokenToPrice, int decimalPlaces) {
        uniswapV3Pool = pool;
        require(tokenToPrice == 0 || tokenToPrice == 1, "tokenToPrice not 0 or 1");
        uniswapTokenToPrice = tokenToPrice;
        // We want latestPrice() to return WAD-fixed-point (18-decimal-place) numbers.  So, eg, if Uniswap's output numbers
        // include 3 decimal places (ie, are already scaled by 10**3), we need to scale them by another 10**15:
        uniswapScaleFactor = uint128(decimalPlaces >= 0 ?
            WAD / 10 ** uint(decimalPlaces) :
            WAD * 10 ** uint(-decimalPlaces));
    }

    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        int24 twapTick = OracleLibrary.consult(address(uniswapV3Pool), UNISWAP_TWAP_PERIOD);
        //console.log("twapTick:");
        //console.log(uint(int(twapTick)));
        //console.log(uniswapTokenToPrice);
        price = uniswapTokenToPrice == 1 ?
            OracleLibrary.getQuoteAtTick(twapTick, uniswapScaleFactor, uniswapV3Pool.token1(), uniswapV3Pool.token0()) :
            OracleLibrary.getQuoteAtTick(twapTick, uniswapScaleFactor, uniswapV3Pool.token0(), uniswapV3Pool.token1());
        //console.log("price:");
        //console.log(price);
        (,, uint16 observationIndex,,,,) = uniswapV3Pool.slot0();
        (updateTime,,,) = uniswapV3Pool.observations(observationIndex);
        //console.log("updateTime:");
        //console.log(updateTime);
    }
}
