// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Oracle.sol";

interface IMakerPriceFeed {
    function read() external view returns (bytes32);
}

/**
 * @title MakerOracle
 */
contract MakerOracle is Oracle {
    using SafeMath for uint;

    IMakerPriceFeed public makerMedianizer;

    constructor(address medianizer) public
    {
        makerMedianizer = IMakerPriceFeed(medianizer);
    }

    function latestPrice() public override view returns (uint) {
        // From https://studydefi.com/read-maker-medianizer/:
        return uint(makerMedianizer.read());     // No need to scale, medianizer price is already 18 dec places
    }
}
