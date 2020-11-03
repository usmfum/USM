// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

library Median {
    function median(uint[3] memory xs)
        internal pure returns (uint)
    {
        require(xs.length == 3, "Only 3 supported for now");

        uint a = xs[0];
        uint b = xs[1];
        uint c = xs[2];
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}
