pragma solidity ^0.6.7;

import "@openzeppelin/contracts/math/SafeMath.sol";

library WadMath {
    using SafeMath for uint;

    uint public constant WAD = 10 ** 18;

    uint private constant WAD_OVER_10 = WAD / 10;
    uint private constant WAD_OVER_20 = WAD / 20;
    uint private constant HALF_TO_THE_ONE_TENTH = 933032991536807416;

    //rounds to zero if x*y < WAD / 2
    function wadMul(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(y)).add(WAD.div(2))).div(WAD);
    }

    //rounds to zero if x/y < WAD / 2
    function wadDiv(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(WAD)).add(y.div(2))).div(y);
    }

    function wadMax(uint x, uint y) internal pure returns (uint) {
        return (x > y ? x : y);
    }

    function wadMin(uint x, uint y) internal pure returns (uint) {
        return (x < y ? x : y);
    }

    function wadHalfExp(uint power) internal pure returns (uint) {
        return wadHalfExp(power, type(uint).max);
    }

    //returns a loose but "gas-efficient" approximation of 0.5**power, where power is rounded to the nearest 0.1, and is capped
    //at maxPower.  Note that power is WAD-scaled (eg, 2.7364 * WAD), but maxPower is just a plain unscaled uint (eg, 10).
    function wadHalfExp(uint power, uint maxPower) internal pure returns (uint) {
        require(power >= 0, "power must be positive");
        uint powerInTenths = (power + WAD_OVER_20) / WAD_OVER_10;
        require(powerInTenths >= 0, "powerInTenths must be positive");
        if (powerInTenths > 10 * maxPower) {
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
            x = wadMul(x, x);

            if (n % 2 != 0) {
                z = wadMul(z, x);
            }
        }
    }
}
