// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract Oracle {
    function latestPrice() public virtual view returns (uint price, uint updateTime);    // Prices WAD-scaled - 18 dec places

    function refreshPrice() public virtual returns (uint price, uint updateTime) {
        (price, updateTime) = latestPrice();    // Default implementation doesn't do any cacheing.  But override as needed
    }
}
