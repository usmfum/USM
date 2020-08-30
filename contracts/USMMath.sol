// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import "./DecimalMath.sol";

contract USMMath {
    using DecimalMath for DecimalMath.UFixed;
    using DecimalMath for uint;

    DecimalMath.UFixed public ONE                   = DecimalMath.UFixed({ value: DecimalMath.UNIT });
    DecimalMath.UFixed public ONE_TENTH             = DecimalMath.UFixed({ value: DecimalMath.UNIT / 10 });
    DecimalMath.UFixed public HALF_TO_THE_ONE_TENTH = DecimalMath.UFixed({ value: 933032991536807415981343266 });    // Basically round(0.5**0.1 * UNIT), except Python doesn't calc that quite precisely so why not hardcode it here (using good old wolframalpha.com)

    /**
     * @dev Returns a loose but "gas-efficient" approximation of 0.5**power, where:
     *   1. Both input and output are in fixed-point format, shifted by SHIFT decimal digits.  Eg, input power_shifted = 1400000000000000000 represents power = 1400000000000000000 / 10**18 = 1.4, so returns approx (0.5**1.4) * 10**18 = 378929141627599521
     *   2. power is rounded to the nearest 10th: power = 0.462 is treated as power = 0.5
     *   3. Large values of power (> max_power) just return 0, since 0.5**large_power =~ 0
     */ 
    function half_exp_approx(DecimalMath.UFixed memory power, DecimalMath.UFixed memory max_power) public view returns (DecimalMath.UFixed memory){
        require(power.value >= 0); // Why?
        DecimalMath.UFixed memory power_in_tenths = power.addd(ONE_TENTH.divd(2)).divd(ONE_TENTH);   // After this, power_in_tenths must be a non-negative integer
        if (power_in_tenths.value > max_power.value * 10) return uint(0).toUFixed();
        else return half_to_the_one_tenth_exp_approx(power_in_tenths);
    }

    /// @dev power is an fixed point number; return is a fixed point number.
    function half_to_the_one_tenth_exp_approx(DecimalMath.UFixed memory power) public view returns (DecimalMath.UFixed memory) {
        if (power.value == 0) return ONE;
        else {
            DecimalMath.UFixed memory sqrt = half_to_the_one_tenth_exp_approx(power.divd(2));
            DecimalMath.UFixed memory result = sqrt.muld(sqrt);
            if (power.value % 2 == 1) result = result.muld(HALF_TO_THE_ONE_TENTH);
            return result;
        }
    }
}