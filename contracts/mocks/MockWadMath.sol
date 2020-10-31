// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

//import "@openzeppelin/contracts/math/SafeMath.sol";
import "../WadMath.sol";
//import "@nomiclabs/buidler/console.sol";


/**
 * @title Mock Buffered Token
 * @author Alberto Cuesta Cañada (@acuestacanada)
 * @notice This contract gives access to the internal functions of USM for testing
 */
contract MockWadMath {
    using WadMath for uint;

    function wadSqrt(uint x) public pure returns (uint) {
        return x.wadSqrt();
    }
}
