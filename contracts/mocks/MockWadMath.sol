// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "../WadMath.sol";

/**
 * @title MockWadMath
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice This contract gives access to the internal functions of WadMath for testing
 */
contract MockWadMath {
    using WadMath for uint;

    function wadCbrtDown(uint x) public pure returns (uint y) {
        y = x.wadCbrtDown();
    }

    function wadCbrtUp(uint x) public pure returns (uint y) {
        y = x.wadCbrtUp();
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
