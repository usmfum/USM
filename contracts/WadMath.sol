pragma solidity ^0.6.7;

import "@openzeppelin/contracts/math/SafeMath.sol";

library WadMath {
    using SafeMath for uint;

    uint constant WAD = 10 ** 18;
    uint constant SHIFT                         = 32;            // Number of binary digits by which fixed-decimal inputs & outputs are shifted.
    uint constant ONE_TENTH_SHIFTED             = 429496730;
    uint constant HALF_TO_THE_ONE_TENTH_SHIFTED = 4007346185;

    //rounds to zero if x*y < WAD / 2
    function wadMul(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(y)).add(WAD.div(2))).div(WAD);
    }

    //rounds to zero if x*y < WAD / 2
    function wadDiv(uint x, uint y) internal pure returns (uint) {
        return ((x.mul(WAD)).add(y.div(2))).div(y);
    }


    function toPowerShifted(uint224 x) internal pure returns (uint) {
        return uint(x) << SHIFT;
    }

    function fromPowerShifted(uint x) internal pure returns (uint) {
        return x >> SHIFT;
    }

    /** 
     * @dev Returns a loose but "gas-efficient" approximation of 0.5**power, where:
     * 1. Both input and output are in fixed-point format, shifted by SHIFT binary digits.  Eg, input power_shifted = 6012954214 represents power = 6012954214 / 2**32 = 1.4, so returns approx (0.5**1.4) * (2**32) = 1627488271
     * 2. power is rounded to the nearest 10th: power = 0.462 is treated as power = 0.5
     * 3. Large values of power (> max_power) just return 0, since 0.5**large_power =~ 0
    */
    function half_exp_approx(uint224 x) internal pure returns(uint) {
        uint power_in_tenths = (toPowerShifted(x) + (ONE_TENTH_SHIFTED / 2)); // ONE_TENTH_SHIFTED   # After this, power_in_tenths must be a non-negative integer
        return fromPowerShifted(half_to_the_one_tenth_exp_approx(power_in_tenths));
    }

    /**
     * @dev power is an unshifted, non-negative integer; return value is shifted, ie, multiplied by 2**SHIFT.
     */ 
    function half_to_the_one_tenth_exp_approx(uint power) internal pure returns(uint) {
        if (power == 0) return 1 << SHIFT;
        else {
            uint sqrt = half_to_the_one_tenth_exp_approx(power / 2);
            uint result = (sqrt * sqrt) >> SHIFT;
            if (power % 2 == 1) result = (result * HALF_TO_THE_ONE_TENTH_SHIFTED) >> SHIFT;
            return result;
        }
    }
}