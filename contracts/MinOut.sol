// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library MinOut {
    uint public constant ZEROES_PLUS_LIMIT_PRICE_DIGITS = 1e11; // 4 digits all 0s, + 7 digits to specify the limit price
    uint public constant LIMIT_PRICE_DIGITS = 1e7;              // 7 digits to specify the limit price (unscaled)
    uint public constant LIMIT_PRICE_SCALING_FACTOR = 100;      // So, last 7 digits "1234567" / 100 = limit price 12345.67

    function parseMinTokenOut(uint ethIn) internal pure returns (uint minTokenOut) {
        uint minPrice = ethIn % ZEROES_PLUS_LIMIT_PRICE_DIGITS;
        if (minPrice != 0 && minPrice < LIMIT_PRICE_DIGITS) {
            minTokenOut = ethIn * minPrice / LIMIT_PRICE_SCALING_FACTOR;
        }
    }

    function parseMinEthOut(uint tokenIn) internal pure returns (uint minEthOut) {
        uint maxPrice = tokenIn % ZEROES_PLUS_LIMIT_PRICE_DIGITS;
        if (maxPrice != 0 && maxPrice < LIMIT_PRICE_DIGITS) {
            minEthOut = tokenIn * LIMIT_PRICE_SCALING_FACTOR / maxPrice;
        }
    }
}
