// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Fixed point arithmetic library
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 */
library WadMath {
    using SafeMath for uint;

    enum Round {Down, Up}

    uint private constant WAD = 10 ** 18;
    uint private constant WAD_MINUS_1 = WAD - 1;
    uint private constant WAD_SQUARED = WAD * WAD;
    uint private constant WAD_SQUARED_MINUS_1 = WAD_SQUARED - 1;
    uint private constant WAD_OVER_10 = WAD / 10;
    uint private constant WAD_OVER_20 = WAD / 20;
    uint private constant HALF_TO_THE_ONE_TENTH = 933032991536807416;
    uint private constant TWO_WAD = 2 * WAD;

    function wadMul(uint x, uint y, Round upOrDown) internal pure returns (uint) {
        return upOrDown == Round.Down ? wadMulDown(x, y) : wadMulUp(x, y);
    }

    function wadMulDown(uint x, uint y) internal pure returns (uint) {
        return x.mul(y) / WAD;
    }

    function wadMulUp(uint x, uint y) internal pure returns (uint) {
        return (x.mul(y)).add(WAD_MINUS_1) / WAD;
    }

    function wadSquaredDown(uint x) internal pure returns (uint) {
        return (x.mul(x)) / WAD;
    }

    function wadSquaredUp(uint x) internal pure returns (uint) {
        return (x.mul(x)).add(WAD_MINUS_1) / WAD;
    }

    function wadCubedDown(uint x) internal pure returns (uint) {
        return (x.mul(x)).mul(x) / WAD_SQUARED;
    }

    function wadCubedUp(uint x) internal pure returns (uint) {
        return ((x.mul(x)).mul(x)).add(WAD_SQUARED_MINUS_1) / WAD_SQUARED;
    }

    function wadDiv(uint x, uint y, Round upOrDown) internal pure returns (uint) {
        return upOrDown == Round.Down ? wadDivDown(x, y) : wadDivUp(x, y);
    }

    function wadDivDown(uint x, uint y) internal pure returns (uint) {
        return (x.mul(WAD)).div(y);
    }

    function wadDivUp(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(WAD)).add(y - 1)).div(y);    // Can use "-" instead of sub() since div(y) will catch y = 0 case anyway
    }

    function wadMax(uint x, uint y) internal pure returns (uint) {
        return (x > y ? x : y);
    }

    function wadMin(uint x, uint y) internal pure returns (uint) {
        return (x < y ? x : y);
    }

    function wadHalfExp(uint power) internal pure returns (uint) {
        return wadHalfExp(power, uint(-1));
    }

    // Returns a loose but "gas-efficient" approximation of 0.5**power, where power is rounded to the nearest 0.1, and is
    // capped at maxPower.  Note power is WAD-scaled (eg, 2.7364 * WAD), but maxPower is just a plain unscaled uint (eg, 10).
    // Negative powers are not handled (as implied by power being a uint).
    function wadHalfExp(uint power, uint maxPower) internal pure returns (uint) {
        uint powerInTenthsUnscaled = power.add(WAD_OVER_20) / WAD_OVER_10;
        if (powerInTenthsUnscaled / 10 > maxPower) {
            return 0;
        }
        return wadPow(HALF_TO_THE_ONE_TENTH, powerInTenthsUnscaled);
    }

    // Adapted from rpow() in https://github.com/dapphub/ds-math/blob/master/src/math.sol - thank you!
    //
    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function wadPow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : WAD;

        for (n /= 2; n != 0; n /= 2) {
            x = wadSquaredDown(x);

            if (n % 2 != 0) {
                z = wadMulDown(z, x);
            }
        }
    }

    // Using Newton's method (see eg https://stackoverflow.com/a/8827111/3996653), but with WAD fixed-point math.
    function wadCbrtDown(uint y) internal pure returns (uint root) {
        if (y > 0 ) {
            uint newRoot = y.add(TWO_WAD) / 3;
            uint yTimesWadSquared = y.mul(WAD_SQUARED);
            do {
                root = newRoot;
                newRoot = (root + root + (yTimesWadSquared / (root * root))) / 3;
            } while (newRoot < root);
        }
        //require(root**3 <= y.mul(WAD_SQUARED) && y.mul(WAD_SQUARED) < (root + 1)**3);
    }

    function wadCbrtUp(uint y) internal pure returns (uint root) {
        root = wadCbrtDown(y);
        // The only case where wadCbrtUp(y) *isn't* equal to wadCbrtDown(y) + 1 is when y is a perfect cube; so check for that.
        // These "*"s are safe because: 1. root**3 <= y.mul(WAD_SQUARED), and 2. y.mul(WAD_SQUARED) is calculated (safely) above.
        if (root * root * root != y * WAD_SQUARED ) {
            ++root;
        }
        //require((root - 1)**3 < y.mul(WAD_SQUARED) && y.mul(WAD_SQUARED) <= root**3);
    }
}
