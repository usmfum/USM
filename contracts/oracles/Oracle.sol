// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract Oracle {
    /**
     * @notice Doesn't refresh the price, but returns the latest value available without doing any transactional operations:
     * eg, the price cached by the most recent call to `refreshPrice()`.
     * @return price WAD-scaled - 18 dec places
     */
    function latestPrice() public virtual view returns (uint price, uint updateTime);

    /**
     * @notice Does whatever work or queries will yield the most up-to-date price, and returns it (typically also caching it
     * for `latestPrice()` callers).
     * @return price WAD-scaled - 18 dec places
     */
    function refreshPrice() public virtual returns (uint price, uint updateTime) {
        (price, updateTime) = latestPrice();    // Default implementation doesn't do any caching.  But override as needed
    }
}
