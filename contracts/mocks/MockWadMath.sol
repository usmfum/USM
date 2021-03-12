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

    function wadExpDown(uint y) public pure returns (uint z) {
        z = y.wadExpDown();
    }

    function wadExpUp(uint y) public pure returns (uint z) {
        z = y.wadExpUp();
    }

    function wadPowDown(uint x, uint y) public pure returns (uint z) {
        z = x.wadPowDown(y);
    }

    function wadPowUp(uint x, uint y) public pure returns (uint z) {
        z = x.wadPowUp(y);
    }
}
