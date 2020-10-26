// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CompositeOracle is IOracle, Ownable {
    using SafeMath for uint;

    uint public constant NUM_SOURCES = 3;

    IOracle[NUM_SOURCES] public oracles;
    uint public override decimalShift;

    // The source oracles may have different decimalShifts from us, so we'll need to shift them:
    uint[NUM_SOURCES] private shiftFactors;

    constructor(IOracle[NUM_SOURCES] memory oracles_, uint decimalShift_)
        public
    {
        oracles = oracles_; 
        decimalShift = decimalShift_;

        // We assume here that source oracles never change their decimalShifts!
        for (uint i = 0; i < NUM_SOURCES; ++i) {
            uint shift = decimalShift_ - oracles_[i].decimalShift();
            // We don't currently support a source oracle with more decimal places than the CompositeOracle itself:
            require(shift >= 0, "Source precision too high");
            // If the source is shifted 15 places, and we want 20 places, then we need to multiply its prices by 10**(20-15).
            shiftFactors[i] = 10 ** shift;
        }
    }

    function latestPrice()
        external override view returns (uint)
    {
        // For maximal gas efficiency...
        return median([oracles[0].latestPrice().mul(shiftFactors[0]),
                       oracles[1].latestPrice().mul(shiftFactors[1]),
                       oracles[2].latestPrice().mul(shiftFactors[2])]);
    }

    function median(uint[NUM_SOURCES] memory xs)
        public pure returns (uint)
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
