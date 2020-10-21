// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./IOracle.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract OurUniswapV2SpotOracle is IOracle {
    IUniswapV2Pair public pair;
    uint public override decimalShift;
    uint public scalePriceBy;
    bool public areTokensInReverseOrder;    // Depends on which order the given tokens are canonically sorted by Uniswap - see below

    /**
     * @notice Note that latestPrice() will return the price of tokenA, in terms of tokenB.  Eg, if tokenA = ETH and tokenB = DAI,
     * the returned price will be on the order of $300, not 0.003 (the price of 1 DAI in ETH terms).
     *
     * - decimalShift is, per the IOracle interface, the intended scaling of values returned by latestPrice().
     * - scalePriceBy is the amount by which latestPrice() internally scales the ratio of reserves in calculating the price.
     *
     * Eg: suppose tokenA = ETH (whose reserves are stored scaled by 10**18), tokenB = USDT (stored scaled by 10**6), and the
     * requested decimalShift is 18.  Then the user needs to pass in scalePriceBy = 10**30, so that when latestPrice() performs
     * the following calculation, it gives the desired decimalShift of 18 digits:
     *
     *     price [to be scaled by 10**18] = usdtReserve [scaled by 10**6] * scalePriceBy [10**30] / ethReserve [scaled by 10**18]
     *     eg: 266882627504236 [266.9m * 10**6 UDST] * 10**30 / 706185532732816562962304 [706k * 10**18 ETH] = $377.92 * 10**18
     *
     * Mainnet details:
     * Token contracts - pass these to the constructor below:
     * - ETH (WETH): 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 (18 decimals)
     * - USDT: 0xdac17f958d2ee523a2206206994597c13d831ec7 (6 decimals)
     * - USDC: 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 (6 decimals)
     * - DAI: 0x6b175474e89094c44da98b954eedeac495271d0f (18 decimals)
     * Pair contracts:
     * - ETH/USDT: 0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852 (or 0x6c3e4cb2e96b01f4b866965a91ed4437839a121a?)
     * - USDC/ETH: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc (or 0x7fba4b8dc5e7616e59622806932dbea72537a56b?)
     * - DAI/ETH: 0xa478c2975ab1ea89e8196811f51a7b7ade33eb11 (or 0xa1484c3aa22a66c62b77e0ae78e15258bd0cb711?)
     */
    constructor(address factory, address tokenA, address tokenB, uint decimalShift_, uint scalePriceBy_) public {
        pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        decimalShift = decimalShift_;
        scalePriceBy = scalePriceBy_;

        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        areTokensInReverseOrder = (token0 == tokenB);
    }

    function latestPrice() external override view returns (uint) {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint reserve0, uint reserve1,) = pair.getReserves();
        (uint reserveA, uint reserveB) = areTokensInReverseOrder ? (reserve1, reserve0) : (reserve0, reserve1);
        return reserveB * scalePriceBy / reserveA;      // See the "USDT * scalePriceBy / ETH" example above
    }
}
