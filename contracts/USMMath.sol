// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.10;

import "./DecimalMath.sol";
pragma experimental ABIEncoderV2;

contract USMMath is DecimalMath {
    UFixed public ONE                   = UFixed({ value: UNIT });
    UFixed public ONE_TENTH             = UFixed({ value: UNIT / 10 });
    UFixed public HALF_TO_THE_ONE_TENTH = UFixed({ value: 933032991536807415981343266 });    // Basically round(0.5**0.1 * UNIT), except Python doesn't calc that quite precisely so why not hardcode it here (using good old wolframalpha.com)

    /**
     * @dev Returns a loose but "gas-efficient" approximation of 0.5**power, where:
     *   1. Both input and output are in fixed-point format, shifted by SHIFT decimal digits.  Eg, input power_shifted = 1400000000000000000 represents power = 1400000000000000000 / 10**18 = 1.4, so returns approx (0.5**1.4) * 10**18 = 378929141627599521
     *   2. power is rounded to the nearest 10th: power = 0.462 is treated as power = 0.5
     *   3. Large values of power (> max_power) just return 0, since 0.5**large_power =~ 0
     */ 
    function half_exp_approx(UFixed memory power, UFixed memory max_power) public view returns (UFixed memory){
        require(power.value >= 0); // Why?
        UFixed memory power_in_tenths = divd(addd(power, divd(ONE_TENTH, 2)), ONE_TENTH);   // After this, power_in_tenths must be a non-negative integer
        if (power_in_tenths.value > max_power.value * 10) return toUFixed(0);
        else return half_to_the_one_tenth_exp_approx(power_in_tenths);
    }

    /// @dev power is an fixed point number; return is a fixed point number.
    function half_to_the_one_tenth_exp_approx(UFixed memory power) public view returns (UFixed memory) {
        if (power.value == 0) return ONE;
        else {
            UFixed memory sqrt = half_to_the_one_tenth_exp_approx(divd(power, 2));
            UFixed memory result = muld(sqrt, sqrt);
            if (power.value % 2 == 1) result = muld(result, HALF_TO_THE_ONE_TENTH);
            return result;
        }
    }
}