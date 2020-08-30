// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/math/SafeMath.sol";


/// @dev Implements simple fixed point math mul and div operations for 27 decimals.
library DecimalMath {
    using SafeMath for uint256;

    uint256 constant internal UNIT = 1e18;

    struct UFixed {
        uint256 value;
    }

    /// @dev Creates a fixed point number from an unsiged integer. `toUFixed(1) = 10^-27`
    /// Converting from fixed point to integer can be done with `UFixed.value / UNIT` and `UFixed.value % UNIT`
    function toUFixed(uint256 x) internal pure returns (UFixed memory) {
        return UFixed({
            value: x
        });
    }

    /// @dev Greater than.
    function gt(UFixed memory x, UFixed memory y) internal pure returns (bool) {
        return x.value > y.value;
    }

    /// @dev Greater than.
    function gt(UFixed memory x, uint y) internal pure returns (bool) {
        return x.value > y.mul(UNIT);
    }

    /// @dev Greater than.
    function gt(uint x, UFixed memory y) internal pure returns (bool) {
        return x.mul(UNIT) > y.value;
    }

    /// @dev Greater or equal.
    function geq(UFixed memory x, UFixed memory y) internal pure returns (bool) {
        return x.value >= y.value;
    }

    /// @dev Greater or equal.
    function geq(UFixed memory x, uint y) internal pure returns (bool) {
        return x.value >= y.mul(UNIT);
    }

    /// @dev Greater or equal.
    function geq(uint x, UFixed memory y) internal pure returns (bool) {
        return x.mul(UNIT) >= y.value;
    }

    /// @dev Less than.
    function lt(UFixed memory x, UFixed memory y) internal pure returns (bool) {
        return x.value < y.value;
    }

    /// @dev Less than.
    function lt(UFixed memory x, uint y) internal pure returns (bool) {
        return x.value < y.mul(UNIT);
    }

    /// @dev Less than.
    function lt(uint x, UFixed memory y) internal pure returns (bool) {
        return x.mul(UNIT) < y.value;
    }

    /// @dev Less or equal.
    function leq(UFixed memory x, UFixed memory y) internal pure returns (bool) {
        return x.value <= y.value;
    }

    /// @dev Less or equal.
    function leq(uint x, UFixed memory y) internal pure returns (bool) {
        return x.mul(UNIT) <= y.value;
    }

    /// @dev Less or equal.
    function leq(UFixed memory x, uint y) internal pure returns (bool) {
        return x.value <= y.mul(UNIT);
    }

    /// @dev Multiplies x and y.
    /// @param x An unsigned integer.
    /// @param y A fixed point number.
    /// @return An unsigned integer.
    function muld(uint256 x, UFixed memory y) internal pure returns (uint256) {
        return x.mul(y.value).div(UNIT);
    }

    /// @dev Multiplies x and y.
    /// @param x A fixed point number.
    /// @param y A fixed point number.
    /// @return A fixed point number.
    function muld(UFixed memory x, UFixed memory y) internal pure returns (UFixed memory) {
        return UFixed({
            value: muld(x.value, y)
        });
    }

    /// @dev Multiplies x and y.
    /// @param x A fixed point number.
    /// @param y An unsigned integer.
    /// @return A fixed point number.
    function muld(UFixed memory x, uint y) internal pure returns (UFixed memory) {
        return muld(x, toUFixed(y));
    }

    /// @dev Divides x by y.
    /// @param x An unsigned integer.
    /// @param y A fixed point number.
    /// @return An unsigned integer.
    function divd(uint256 x, UFixed memory y) internal pure returns (uint256) {
        return x.mul(UNIT).div(y.value);
    }

    /// @dev Divides x by y.
    /// @param x A fixed point number.
    /// @param y A fixed point number.
    /// @return A fixed point number.
    function divd(UFixed memory x, UFixed memory y) internal pure returns (UFixed memory) {
        return UFixed({
            value: divd(x.value, y)
        });
    }

    /// @dev Divides x by y.
    /// @param x A fixed point number.
    /// @param y An unsigned integer.
    /// @return A fixed point number.
    function divd(UFixed memory x, uint y) internal pure returns (UFixed memory) {
        return divd(x, toUFixed(y));
    }

    /// @dev Divides x by y.
    /// @param x An unsigned integer.
    /// @param y An unsigned integer.
    /// @return A fixed point number.
    function divd(uint256 x, uint256 y) internal pure returns (UFixed memory) {
        return divd(toUFixed(x), y);
    }

    /// @dev Adds x and y.
    /// @param x A fixed point number.
    /// @param y A fixed point number.
    /// @return A fixed point number.
    function addd(UFixed memory x, UFixed memory y) internal pure returns (UFixed memory) {
        return UFixed({
            value: x.value.add(y.value)
        });
    }

    /// @dev Adds x and y.
    /// @param x A fixed point number.
    /// @param y An unsigned integer.
    /// @return A fixed point number.
    function addd(UFixed memory x, uint y) internal pure returns (UFixed memory) {
        return addd(x, toUFixed(y));
    }

    /// @dev Subtracts x and y.
    /// @param x A fixed point number.
    /// @param y A fixed point number.
    /// @return A fixed point number.
    function subd(UFixed memory x, UFixed memory y) internal pure returns (UFixed memory) {
        return UFixed({
            value: x.value.sub(y.value)
        });
    }

    /// @dev Subtracts x and y.
    /// @param x A fixed point number.
    /// @param y An unsigned integer.
    /// @return A fixed point number.
    function subd(UFixed memory x, uint y) internal pure returns (UFixed memory) {
        return subd(x, toUFixed(y));
    }

    /// @dev Subtracts x and y.
    /// @param x An unsigned integer.
    /// @param y A fixed point number.
    /// @return A fixed point number.
    function subd(uint x, UFixed memory y) internal pure returns (UFixed memory) {
        return subd(toUFixed(x), y);
    }

    /// @dev Divides x between y, rounding up to the closest representable number.
    /// @param x An unsigned integer.
    /// @param y A fixed point number.
    /// @return An unsigned integer.
    function divdrup(uint256 x, UFixed memory y) internal pure returns (uint256)
    {
        uint256 z = x.mul(1e28).div(y.value); // UNIT * 10
        return (z % 10 > 0) ? z / 10 + 1 : z / 10;
    }

    /// @dev Multiplies x by y, rounding up to the closest representable number.
    /// @param x An unsigned integer.
    /// @param y A fixed point number.
    /// @return An unsigned integer.
    function muldrup(uint256 x, UFixed memory y) internal pure returns (uint256)
    {
        uint256 z = x.mul(y.value).div(1e26); // UNIT / 10
        return (z % 10 > 0) ? z / 10 + 1 : z / 10;
    }

    /// @dev Exponentiation (x**n) by squaring of a fixed point number by an integer.
    /// Taken from https://github.com/dapphub/ds-math/blob/master/src/math.sol. Thanks!
    /// @param x A fixed point number.
    /// @param n An unsigned integer.
    /// @return An unsigned integer.
    function powd(UFixed memory x, uint256 n) internal pure returns (UFixed memory) {
        if (x.value == 0) return toUFixed(0);
        if (n == 0) return toUFixed(UNIT);
        UFixed memory z = n % 2 != 0 ? x : toUFixed(UNIT);

        for (n /= 2; n != 0; n /= 2) {
            x = muld(x, x);

            if (n % 2 != 0) {
                z = muld(z, x);
            }
        }
        return z;
    }
}
