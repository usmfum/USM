// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "@openzeppelin/contracts/math/SafeMath.sol";

library WadMath {
    using SafeMath for uint;

    uint public constant WAD = 10 ** 18;

    //rounds to zero if x*y < WAD / 2
    function wadMul(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(y)).add(WAD.div(2))).div(WAD);
    }

    //rounds to zero if x/y < WAD / 2
    function wadDiv(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(WAD)).add(y.div(2))).div(y);
    }

}