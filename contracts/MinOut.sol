// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library MinOut {
    function parseMinTokenOut(uint ethIn) internal pure returns (uint minTokenOut) {
        uint minPrice = ethIn % 100000000000;
        if (minPrice != 0 && minPrice < 10000000) {
            minTokenOut = ethIn * minPrice / 100;
        }
    }

    function parseMinEthOut(uint tokenIn) internal pure returns (uint minEthOut) {
        uint maxPrice = tokenIn % 100000000000;
        if (maxPrice != 0 && maxPrice < 10000000) {
            minEthOut = tokenIn * 100 / maxPrice;
        }
    }
}
