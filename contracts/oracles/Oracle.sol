// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface Oracle {
    /**
     * @return price WAD-scaled - 18 dec places
     */
    function latestPrice() external view returns (uint price);
}
