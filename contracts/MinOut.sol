// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

library MinOut {
    uint private constant MIN_OUT_FLAG = 0x539;

    function inferMinTokenOut(uint ethIn) internal pure returns (uint minTokenOut) {
        if (ethIn % 10000 == MIN_OUT_FLAG) {
            minTokenOut = ethIn * ((ethIn / 10000) % 10000000) / 100;
        }
    }

    function inferMinEthOut(uint tokenIn) internal pure returns (uint minEthOut) {
        if (tokenIn % 10000 == MIN_OUT_FLAG) {
            minEthOut = tokenIn * 100 / ((tokenIn / 10000) % 10000000);
        }
    }
}
