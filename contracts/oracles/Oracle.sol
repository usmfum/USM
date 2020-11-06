// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

abstract contract Oracle {
    function latestPrice() public virtual view returns (uint);      // Prices must be WAD-scaled - 18 decimal places
}
