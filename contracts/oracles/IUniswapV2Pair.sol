// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

interface IUniswapV2Pair {
    function getReserves(address factory, address tokenA, address tokenB) external view returns (uint reserveA, uint reserveB);
}
