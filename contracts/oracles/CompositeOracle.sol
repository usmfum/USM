// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CompositeOracle is IOracle, Ownable {
    using SafeMath for uint;

    IOracle[] public oracles;
    uint public override decimalShift;

    // The source oracles may have different decimalShifts from us, so we'll need to shift them:
    bool[] private shiftSigns;
    uint[] private shiftFactors;

    constructor(IOracle[] memory oracles_, uint decimalShift_)
        public
    {
        require(oracles_.length == 3, "Only 3 supported for now");
        oracles = oracles_; 
        decimalShift = decimalShift_;

        // We assume here that source oracles never change their decimalShifts!
        shiftSigns = new bool[](oracles_.length);
        shiftFactors = new uint[](oracles_.length);
        for (uint i = 0; i < oracles_.length; ++i) {
            uint shift = decimalShift_ - oracles_[i].decimalShift();
            shiftSigns[i] = shift > 0;
            // If the source is shifted 15 places, and we want 20 places, then we need to *multiply* its prices by 10**(20-15).
            // Or, if the source is shifted 30 places, and we want 20 places, then we need to *divide* its prices by 10**(30-20).
            shiftFactors[i] = 10 ** (shiftSigns[i] ? shift : -shift);
        }
    }

    function latestPrice()
        external override view returns (uint)
    {
        uint[] memory sourcePrices = new uint[](oracles.length);
        for (uint i = 0; i < oracles.length; ++i) {
            uint rawSourcePrice = oracles[i].latestPrice();
            sourcePrices[i] = (shiftSigns[i] ? rawSourcePrice.mul(shiftFactors[i]) : rawSourcePrice.div(shiftFactors[i]));
        }
        return median(sourcePrices);
    }

    function median(uint[] memory xs)
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
