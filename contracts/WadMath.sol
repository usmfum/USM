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
    uint private constant LOG_2_WAD_SCALED = 158961593653514369813532673448321674075;   // log_2(10**18) * 2**121
    uint private constant LOG_2_E_SCALED = 3835341275459348169893510517860103418;       // log_2(e) * 2**121
    uint private constant LOG_2_E_SCALED_OVER_WAD = 3835341275459348170;                // log_2(e) * 2**121 / 10**18

    uint private constant UINT128_MAX = 2 ** 128 - 1;   // Should really be type(uint128).max, but that needs Solidity 0.6.8...

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

    /**
     * Returns the (approximate!) natural logarithm of x, where both x and the return value are in WAD fixed-point form.
     */
    function wadLog(uint x) internal pure returns (int z) {
        require(x <= UINT128_MAX, "x overflow");
        z = (int(log_2(uint128(x))) - int(LOG_2_WAD_SCALED)) / int(LOG_2_E_SCALED_OVER_WAD);
    }

    /**
     * Raise e to the given power y (approximately!), specified in WAD 18-digit fixed-point form, and return the result in,
     * again, WAD form.
     *
     * This library works only on positive uint inputs.  If you have a negative exponent (y < 0), you can calculate it using
     * this identity:
     *
     *     wadExp(y < 0) = 1 / wadExp(-y > 0) = WAD.div(wadExp(-y > 0))
     */
    function wadExp(uint y) internal pure returns (uint z) {
        uint exponent = LOG_2_WAD_SCALED.add(wadMulDown(y, LOG_2_E_SCALED));
        require(exponent <= UINT128_MAX, "exponent overflow");
        z = pow_2(uint128(exponent));
    }

    /**
     * Raise given number x to power y (approximately!), both in WAD 18-digit fixed-point form, and return the result in,
     * again, WAD form.
     *
     * This library works only on positive uint inputs.  If you have a negative base (x < 0) or a negative exponent (y < 0),
     * you can calculate them using these identities:
     *
     *     wadExp(x < 0, y) = -wadExp(-x > 0, y)
     *     wadExp(x, y < 0) = 1 / wadExp(x, -y > 0) = WAD.div(wadExp(x, -y > 0))
     */
    function wadExp(uint x, uint y) internal pure returns (uint z) {
        require(x <= UINT128_MAX, "x overflow");
        uint logX = log_2(uint128(x));
        uint exponent;
        if (logX >= LOG_2_WAD_SCALED) {
            exponent = LOG_2_WAD_SCALED.add(wadMulDown(y, logX - LOG_2_WAD_SCALED));
        } else {
            exponent = LOG_2_WAD_SCALED.sub(wadMulDown(y, LOG_2_WAD_SCALED - logX));
        }
        require(exponent <= UINT128_MAX, "exponent overflow");
        z = pow_2(uint128(exponent));
    }

    /* ____________________ Exponential/logarithm fns borrowed from Yield Protocol ____________________
     *
     * See https://github.com/yieldprotocol/fyDai/blob/master/contracts/pool/YieldMath.sol for Yield's original code.
     */

    /**
     * Calculate base 2 logarithm of an unsigned 128-bit integer number.  Revert
     * in case x is zero.
     *
     * @param x number to calculate base 2 logarithm of
     * @return base 2 logarithm of x, multiplied by 2^121
     */
    function log_2(uint128 x)
        internal pure returns (uint128)
    {
        require (x != 0, "x = 0");

        uint b = x;

        uint l = 0xFE000000000000000000000000000000;

        if (b < 0x10000000000000000) {l -= 0x80000000000000000000000000000000; b <<= 64;}
        if (b < 0x1000000000000000000000000) {l -= 0x40000000000000000000000000000000; b <<= 32;}
        if (b < 0x10000000000000000000000000000) {l -= 0x20000000000000000000000000000000; b <<= 16;}
        if (b < 0x1000000000000000000000000000000) {l -= 0x10000000000000000000000000000000; b <<= 8;}
        if (b < 0x10000000000000000000000000000000) {l -= 0x8000000000000000000000000000000; b <<= 4;}
        if (b < 0x40000000000000000000000000000000) {l -= 0x4000000000000000000000000000000; b <<= 2;}
        if (b < 0x80000000000000000000000000000000) {l -= 0x2000000000000000000000000000000; b <<= 1;}

        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000000;}
        /* Precision reduced to 64 bits
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x1000;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x800;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x400;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x200;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x100;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x80;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x40;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x20;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x10;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x8;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x4;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) {b >>= 1; l |= 0x2;}
        b = b * b >> 127; if (b >= 0x100000000000000000000000000000000) l |= 0x1;
        */

        return uint128(l);
    }

    /**
     * Calculate 2 raised into given power.
     *
     * @param x power to raise 2 into, multiplied by 2^121
     * @return 2 raised into given power
     */
    function pow_2(uint128 x)
        internal pure returns (uint128)
    {
        uint r = 0x80000000000000000000000000000000;
        if (x & 0x1000000000000000000000000000000 > 0) r = r * 0xb504f333f9de6484597d89b3754abe9f >> 127;
        if (x & 0x800000000000000000000000000000 > 0) r = r * 0x9837f0518db8a96f46ad23182e42f6f6 >> 127;
        if (x & 0x400000000000000000000000000000 > 0) r = r * 0x8b95c1e3ea8bd6e6fbe4628758a53c90 >> 127;
        if (x & 0x200000000000000000000000000000 > 0) r = r * 0x85aac367cc487b14c5c95b8c2154c1b2 >> 127;
        if (x & 0x100000000000000000000000000000 > 0) r = r * 0x82cd8698ac2ba1d73e2a475b46520bff >> 127;
        if (x & 0x80000000000000000000000000000 > 0) r = r * 0x8164d1f3bc0307737be56527bd14def4 >> 127;
        if (x & 0x40000000000000000000000000000 > 0) r = r * 0x80b1ed4fd999ab6c25335719b6e6fd20 >> 127;
        if (x & 0x20000000000000000000000000000 > 0) r = r * 0x8058d7d2d5e5f6b094d589f608ee4aa2 >> 127;
        if (x & 0x10000000000000000000000000000 > 0) r = r * 0x802c6436d0e04f50ff8ce94a6797b3ce >> 127;
        if (x & 0x8000000000000000000000000000 > 0) r = r * 0x8016302f174676283690dfe44d11d008 >> 127;
        if (x & 0x4000000000000000000000000000 > 0) r = r * 0x800b179c82028fd0945e54e2ae18f2f0 >> 127;
        if (x & 0x2000000000000000000000000000 > 0) r = r * 0x80058baf7fee3b5d1c718b38e549cb93 >> 127;
        if (x & 0x1000000000000000000000000000 > 0) r = r * 0x8002c5d00fdcfcb6b6566a58c048be1f >> 127;
        if (x & 0x800000000000000000000000000 > 0) r = r * 0x800162e61bed4a48e84c2e1a463473d9 >> 127;
        if (x & 0x400000000000000000000000000 > 0) r = r * 0x8000b17292f702a3aa22beacca949013 >> 127;
        if (x & 0x200000000000000000000000000 > 0) r = r * 0x800058b92abbae02030c5fa5256f41fe >> 127;
        if (x & 0x100000000000000000000000000 > 0) r = r * 0x80002c5c8dade4d71776c0f4dbea67d6 >> 127;
        if (x & 0x80000000000000000000000000 > 0) r = r * 0x8000162e44eaf636526be456600bdbe4 >> 127;
        if (x & 0x40000000000000000000000000 > 0) r = r * 0x80000b1721fa7c188307016c1cd4e8b6 >> 127;
        if (x & 0x20000000000000000000000000 > 0) r = r * 0x8000058b90de7e4cecfc487503488bb1 >> 127;
        if (x & 0x10000000000000000000000000 > 0) r = r * 0x800002c5c8678f36cbfce50a6de60b14 >> 127;
        if (x & 0x8000000000000000000000000 > 0) r = r * 0x80000162e431db9f80b2347b5d62e516 >> 127;
        if (x & 0x4000000000000000000000000 > 0) r = r * 0x800000b1721872d0c7b08cf1e0114152 >> 127;
        if (x & 0x2000000000000000000000000 > 0) r = r * 0x80000058b90c1aa8a5c3736cb77e8dff >> 127;
        if (x & 0x1000000000000000000000000 > 0) r = r * 0x8000002c5c8605a4635f2efc2362d978 >> 127;
        if (x & 0x800000000000000000000000 > 0) r = r * 0x800000162e4300e635cf4a109e3939bd >> 127;
        if (x & 0x400000000000000000000000 > 0) r = r * 0x8000000b17217ff81bef9c551590cf83 >> 127;
        if (x & 0x200000000000000000000000 > 0) r = r * 0x800000058b90bfdd4e39cd52c0cfa27c >> 127;
        if (x & 0x100000000000000000000000 > 0) r = r * 0x80000002c5c85fe6f72d669e0e76e411 >> 127;
        if (x & 0x80000000000000000000000 > 0) r = r * 0x8000000162e42ff18f9ad35186d0df28 >> 127;
        if (x & 0x40000000000000000000000 > 0) r = r * 0x80000000b17217f84cce71aa0dcfffe7 >> 127;
        if (x & 0x20000000000000000000000 > 0) r = r * 0x8000000058b90bfc07a77ad56ed22aaa >> 127;
        if (x & 0x10000000000000000000000 > 0) r = r * 0x800000002c5c85fdfc23cdead40da8d6 >> 127;
        if (x & 0x8000000000000000000000 > 0) r = r * 0x80000000162e42fefc25eb1571853a66 >> 127;
        if (x & 0x4000000000000000000000 > 0) r = r * 0x800000000b17217f7d97f692baacded5 >> 127;
        if (x & 0x2000000000000000000000 > 0) r = r * 0x80000000058b90bfbead3b8b5dd254d7 >> 127;
        if (x & 0x1000000000000000000000 > 0) r = r * 0x8000000002c5c85fdf4eedd62f084e67 >> 127;
        if (x & 0x800000000000000000000 > 0) r = r * 0x800000000162e42fefa58aef378bf586 >> 127;
        if (x & 0x400000000000000000000 > 0) r = r * 0x8000000000b17217f7d24a78a3c7ef02 >> 127;
        if (x & 0x200000000000000000000 > 0) r = r * 0x800000000058b90bfbe9067c93e474a6 >> 127;
        if (x & 0x100000000000000000000 > 0) r = r * 0x80000000002c5c85fdf47b8e5a72599f >> 127;
        if (x & 0x80000000000000000000 > 0) r = r * 0x8000000000162e42fefa3bdb315934a2 >> 127;
        if (x & 0x40000000000000000000 > 0) r = r * 0x80000000000b17217f7d1d7299b49c46 >> 127;
        if (x & 0x20000000000000000000 > 0) r = r * 0x8000000000058b90bfbe8e9a8d1c4ea0 >> 127;
        if (x & 0x10000000000000000000 > 0) r = r * 0x800000000002c5c85fdf4745969ea76f >> 127;
        if (x & 0x8000000000000000000 > 0) r = r * 0x80000000000162e42fefa3a0df5373bf >> 127;
        if (x & 0x4000000000000000000 > 0) r = r * 0x800000000000b17217f7d1cff4aac1e1 >> 127;
        if (x & 0x2000000000000000000 > 0) r = r * 0x80000000000058b90bfbe8e7db95a2f1 >> 127;
        if (x & 0x1000000000000000000 > 0) r = r * 0x8000000000002c5c85fdf473e61ae1f8 >> 127;
        if (x & 0x800000000000000000 > 0) r = r * 0x800000000000162e42fefa39f121751c >> 127;
        if (x & 0x400000000000000000 > 0) r = r * 0x8000000000000b17217f7d1cf815bb96 >> 127;
        if (x & 0x200000000000000000 > 0) r = r * 0x800000000000058b90bfbe8e7bec1e0d >> 127;
        if (x & 0x100000000000000000 > 0) r = r * 0x80000000000002c5c85fdf473dee5f17 >> 127;
        if (x & 0x80000000000000000 > 0) r = r * 0x8000000000000162e42fefa39ef5438f >> 127;
        if (x & 0x40000000000000000 > 0) r = r * 0x80000000000000b17217f7d1cf7a26c8 >> 127;
        if (x & 0x20000000000000000 > 0) r = r * 0x8000000000000058b90bfbe8e7bcf4a4 >> 127;
        if (x & 0x10000000000000000 > 0) r = r * 0x800000000000002c5c85fdf473de72a2 >> 127;
        /* Precision reduced to 64 bits
        if (x & 0x8000000000000000 > 0) r = r * 0x80000000000000162e42fefa39ef3765 >> 127;
        if (x & 0x4000000000000000 > 0) r = r * 0x800000000000000b17217f7d1cf79b37 >> 127;
        if (x & 0x2000000000000000 > 0) r = r * 0x80000000000000058b90bfbe8e7bcd7d >> 127;
        if (x & 0x1000000000000000 > 0) r = r * 0x8000000000000002c5c85fdf473de6b6 >> 127;
        if (x & 0x800000000000000 > 0) r = r * 0x800000000000000162e42fefa39ef359 >> 127;
        if (x & 0x400000000000000 > 0) r = r * 0x8000000000000000b17217f7d1cf79ac >> 127;
        if (x & 0x200000000000000 > 0) r = r * 0x800000000000000058b90bfbe8e7bcd6 >> 127;
        if (x & 0x100000000000000 > 0) r = r * 0x80000000000000002c5c85fdf473de6a >> 127;
        if (x & 0x80000000000000 > 0) r = r * 0x8000000000000000162e42fefa39ef35 >> 127;
        if (x & 0x40000000000000 > 0) r = r * 0x80000000000000000b17217f7d1cf79a >> 127;
        if (x & 0x20000000000000 > 0) r = r * 0x8000000000000000058b90bfbe8e7bcd >> 127;
        if (x & 0x10000000000000 > 0) r = r * 0x800000000000000002c5c85fdf473de6 >> 127;
        if (x & 0x8000000000000 > 0) r = r * 0x80000000000000000162e42fefa39ef3 >> 127;
        if (x & 0x4000000000000 > 0) r = r * 0x800000000000000000b17217f7d1cf79 >> 127;
        if (x & 0x2000000000000 > 0) r = r * 0x80000000000000000058b90bfbe8e7bc >> 127;
        if (x & 0x1000000000000 > 0) r = r * 0x8000000000000000002c5c85fdf473de >> 127;
        if (x & 0x800000000000 > 0) r = r * 0x800000000000000000162e42fefa39ef >> 127;
        if (x & 0x400000000000 > 0) r = r * 0x8000000000000000000b17217f7d1cf7 >> 127;
        if (x & 0x200000000000 > 0) r = r * 0x800000000000000000058b90bfbe8e7b >> 127;
        if (x & 0x100000000000 > 0) r = r * 0x80000000000000000002c5c85fdf473d >> 127;
        if (x & 0x80000000000 > 0) r = r * 0x8000000000000000000162e42fefa39e >> 127;
        if (x & 0x40000000000 > 0) r = r * 0x80000000000000000000b17217f7d1cf >> 127;
        if (x & 0x20000000000 > 0) r = r * 0x8000000000000000000058b90bfbe8e7 >> 127;
        if (x & 0x10000000000 > 0) r = r * 0x800000000000000000002c5c85fdf473 >> 127;
        if (x & 0x8000000000 > 0) r = r * 0x80000000000000000000162e42fefa39 >> 127;
        if (x & 0x4000000000 > 0) r = r * 0x800000000000000000000b17217f7d1c >> 127;
        if (x & 0x2000000000 > 0) r = r * 0x80000000000000000000058b90bfbe8e >> 127;
        if (x & 0x1000000000 > 0) r = r * 0x8000000000000000000002c5c85fdf47 >> 127;
        if (x & 0x800000000 > 0) r = r * 0x800000000000000000000162e42fefa3 >> 127;
        if (x & 0x400000000 > 0) r = r * 0x8000000000000000000000b17217f7d1 >> 127;
        if (x & 0x200000000 > 0) r = r * 0x800000000000000000000058b90bfbe8 >> 127;
        if (x & 0x100000000 > 0) r = r * 0x80000000000000000000002c5c85fdf4 >> 127;
        if (x & 0x80000000 > 0) r = r * 0x8000000000000000000000162e42fefa >> 127;
        if (x & 0x40000000 > 0) r = r * 0x80000000000000000000000b17217f7d >> 127;
        if (x & 0x20000000 > 0) r = r * 0x8000000000000000000000058b90bfbe >> 127;
        if (x & 0x10000000 > 0) r = r * 0x800000000000000000000002c5c85fdf >> 127;
        if (x & 0x8000000 > 0) r = r * 0x80000000000000000000000162e42fef >> 127;
        if (x & 0x4000000 > 0) r = r * 0x800000000000000000000000b17217f7 >> 127;
        if (x & 0x2000000 > 0) r = r * 0x80000000000000000000000058b90bfb >> 127;
        if (x & 0x1000000 > 0) r = r * 0x8000000000000000000000002c5c85fd >> 127;
        if (x & 0x800000 > 0) r = r * 0x800000000000000000000000162e42fe >> 127;
        if (x & 0x400000 > 0) r = r * 0x8000000000000000000000000b17217f >> 127;
        if (x & 0x200000 > 0) r = r * 0x800000000000000000000000058b90bf >> 127;
        if (x & 0x100000 > 0) r = r * 0x80000000000000000000000002c5c85f >> 127;
        if (x & 0x80000 > 0) r = r * 0x8000000000000000000000000162e42f >> 127;
        if (x & 0x40000 > 0) r = r * 0x80000000000000000000000000b17217 >> 127;
        if (x & 0x20000 > 0) r = r * 0x8000000000000000000000000058b90b >> 127;
        if (x & 0x10000 > 0) r = r * 0x800000000000000000000000002c5c85 >> 127;
        if (x & 0x8000 > 0) r = r * 0x80000000000000000000000000162e42 >> 127;
        if (x & 0x4000 > 0) r = r * 0x800000000000000000000000000b1721 >> 127;
        if (x & 0x2000 > 0) r = r * 0x80000000000000000000000000058b90 >> 127;
        if (x & 0x1000 > 0) r = r * 0x8000000000000000000000000002c5c8 >> 127;
        if (x & 0x800 > 0) r = r * 0x800000000000000000000000000162e4 >> 127;
        if (x & 0x400 > 0) r = r * 0x8000000000000000000000000000b172 >> 127;
        if (x & 0x200 > 0) r = r * 0x800000000000000000000000000058b9 >> 127;
        if (x & 0x100 > 0) r = r * 0x80000000000000000000000000002c5c >> 127;
        if (x & 0x80 > 0) r = r * 0x8000000000000000000000000000162e >> 127;
        if (x & 0x40 > 0) r = r * 0x80000000000000000000000000000b17 >> 127;
        if (x & 0x20 > 0) r = r * 0x8000000000000000000000000000058b >> 127;
        if (x & 0x10 > 0) r = r * 0x800000000000000000000000000002c5 >> 127;
        if (x & 0x8 > 0) r = r * 0x80000000000000000000000000000162 >> 127;
        if (x & 0x4 > 0) r = r * 0x800000000000000000000000000000b1 >> 127;
        if (x & 0x2 > 0) r = r * 0x80000000000000000000000000000058 >> 127;
        if (x & 0x1 > 0) r = r * 0x8000000000000000000000000000002c >> 127;
        */

        r >>= 127 - (x >> 121);

        return uint128(r);
    }
}
