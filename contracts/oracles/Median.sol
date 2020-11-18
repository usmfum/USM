// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

library Median {
    /**
     * @notice Currently only supports three inputs
     * @return median value
     */
    function median(uint a, uint b, uint c)
        internal pure returns (uint)
    {
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}
