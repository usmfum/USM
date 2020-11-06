// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

contract MockMakerMedianizer {
    uint public read;

    function set(uint value) external {
        read = value;
    }
}
