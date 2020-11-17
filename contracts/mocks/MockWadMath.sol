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

    function wadCbrtDown(uint x) public pure returns (uint) {
        return x.wadCbrtDown();
    }

    function wadCbrtUp(uint x) public pure returns (uint) {
        return x.wadCbrtUp();
    }
}
