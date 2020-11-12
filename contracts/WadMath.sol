// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Fixed point arithmetic library
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 */
library WadMath {
    using SafeMath for uint;

    uint private constant WAD = 10 ** 18;

    uint private constant WAD_OVER_2 = WAD / 2;
    uint private constant WAD_OVER_10 = WAD / 10;
    uint private constant WAD_OVER_20 = WAD / 20;
    uint private constant HALF_TO_THE_ONE_TENTH = 933032991536807416;
    uint private constant WAD_SQUARED = WAD * WAD;
    uint private constant BIG_INPUT_THRESHOLD = 1 << 93;
    uint private constant TWO_WAD = 2 * WAD;

    //rounds to zero if x*y < WAD / 2
    function wadMul(uint x, uint y) internal pure returns (uint) {
        return (x.mul(y)).add(WAD_OVER_2) / WAD;
    }

    function wadSquared(uint x) internal pure returns (uint) {
        return (x.mul(x)).add(WAD_OVER_2) / WAD;
    }

    function wadCubed(uint x) internal pure returns (uint) {
        return ((x.mul(x)).add(WAD_OVER_2).mul(x)).add(WAD_OVER_2) / WAD_SQUARED;
    }

    //rounds to zero if x/y < WAD / 2
    function wadDiv(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(WAD)).add(y / 2)).div(y);
    }

    function wadHalfExp(uint power) internal pure returns (uint) {
        return wadHalfExp(power, uint(-1));
    }

    //returns a loose but "gas-efficient" approximation of 0.5**power, where power is rounded to the nearest 0.1, and is capped
    //at maxPower.  Note that power is WAD-scaled (eg, 2.7364 * WAD), but maxPower is just a plain unscaled uint (eg, 10).
    function wadHalfExp(uint power, uint maxPower) internal pure returns (uint) {
        require(power >= 0, "power must be positive");
        uint powerInTenths = power.add(WAD_OVER_20) / WAD_OVER_10;
        require(powerInTenths >= 0, "powerInTenths must be positive");
        if (powerInTenths / 10 > maxPower) {
            return 0;
        }
        return wadPow(HALF_TO_THE_ONE_TENTH, powerInTenths);
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
            x = wadSquared(x);

            if (n % 2 != 0) {
                z = wadMul(z, x);
            }
        }
    }

    // Adapted from Lancaster's method: see http://web.archive.org/web/20131227144655/http://metamerist.com/cbrt/cbrt.htm.
    function wadCbrt(uint y) internal pure returns (uint root) {
        if (y > 0 ) {
            // If y > 2**93 or so, our temp products below (around y**4 / WAD_SQUARED) will overflow.  So for these large y
            // values, right-shift y by 3*bitShift digits (so it's manageable), and then (below) left-shift our output root by
            // bitShift digits:
            uint bitShift;
            while (y > BIG_INPUT_THRESHOLD) {
                y >>= 24;
                bitShift += 8;
            }

            uint newRoot = y.add(TWO_WAD) / 3;
            uint rootCubed;
            uint rootCubedPlusY;
            do {
                root = newRoot;
                rootCubed = (root.mul(root) / WAD).mul(root) / WAD;
                rootCubedPlusY = rootCubed.add(y);
                newRoot = root.mul(rootCubedPlusY.add(y)) / rootCubedPlusY.add(rootCubed);
            } while (newRoot < root);
            root <<= bitShift;
        }
    }
}
