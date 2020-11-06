// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

contract MockUniswapV2Pair {
    uint112 internal _reserves0;
    uint112 internal _reserves1;

    function set(uint112 reserves0, uint112 reserves1) external {
        _reserves0 = reserves0;
        _reserves1 = reserves1;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (_reserves0, _reserves1, 0);
    }
}
