// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract Oracle {
    /**
     * @notice Doesn't refresh the price, but returns the latest value available without doing any transactional operations:
     * eg, the price cached by the most recent call to `refreshPrice()`.
     * @return price WAD-scaled - 18 dec places
     * @return updateTime The last time the price was updated.  This is a bit subtle: `price` can change without `updateTime`
     * changing.  Suppose, eg, the current Uniswap v3 TWAP price over the last 10 minutes is $3,000, and then Uniswap records a
     * new trade observation at a price of $3,020.  This will increase the 10-minute TWAP slightly above $3,000, and reset
     * `updateTime` to the new trade's time.  But, over the subsequent 10 minutes the 10-minute TWAP will continue to increase,
     * as more and more of "the last 10 minutes" is at $3,020 rather than $3,000: but because this gradual price change is only
     * driven by the passage of time, not by any new price observations, it will *not* change `updateTime`, which will remain
     * at the time of the $3,020 trade until another trade occurs.
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
