// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface CompoundUniswapAnchoredView {
    /**
     * Stripped-down interface we use for grabbing price from
     * https://github.com/compound-finance/open-oracle/blob/master/contracts/Uniswap/UniswapAnchoredView.sol.  Following the
     * price() function there, this returns 6 decimal places: so a return value of 123456789 represents 123.456789.
     */
    function price(string calldata symbol) external view returns (uint);
}
