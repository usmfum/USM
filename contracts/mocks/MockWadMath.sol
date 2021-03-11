// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../WadMath.sol";

/**
 * @title MockWadMath
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice This contract gives access to the internal functions of WadMath for testing
 */
contract MockWadMath {
    using WadMath for uint;

    function wadSqrtUp(uint x) public pure returns (uint y) {
        y = x.wadSqrtUp();
    }

    function wadSqrtDown(uint x) public pure returns (uint y) {
        y = x.wadSqrtDown();
    }

    function wadLog(uint x) public pure returns (int y) {
        y = x.wadLog();
    }

    function wadExp(uint y) public pure returns (uint z) {
        z = y.wadExp();
    }

    function wadExp(uint x, uint y) public pure returns (uint z) {
        z = x.wadExp(y);
    }
}
