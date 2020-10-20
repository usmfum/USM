// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

interface UniswapAnchoredView {
    function price(string memory symbol) external view returns (uint);
}
