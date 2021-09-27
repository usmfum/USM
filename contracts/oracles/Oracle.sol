// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract Oracle {
    /**
     * @return price WAD-scaled - 18 dec places
     * @return updateTime The last time the price was updated.  This is a bit subtle: `price` can change without `updateTime`
     * changing.  Suppose, eg, the current Uniswap v3 TWAP price over the last 10 minutes is $3,000, and then Uniswap records a
     * new trade observation at a price of $2,980.  This will nudge the 10-minute TWAP slightly below $3,000, and reset
     * `updateTime` to the new trade's time.  However, over the subsequent 10 minutes, the 10-minute TWAP will continue to
     * decrease, as more and more of "the last 10 minutes" is at $2,980 rather than $3,000: but because this gradual price
     * change is only driven by the passage of time, not by any new price observations, it will *not* change `updateTime`,
     * which will remain at the time of the $2,980 trade until another trade occurs.
     */
    function latestPrice() public virtual view returns (uint price, uint updateTime);
}
