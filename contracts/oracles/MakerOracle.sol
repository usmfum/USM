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

    IMakerPriceFeed private medianizer;

    constructor(address medianizer_) public
    {
        medianizer = IMakerPriceFeed(medianizer_);
    }

    function latestPrice() public override view returns (uint) {
        // From https://studydefi.com/read-maker-medianizer/:
        return uint(medianizer.read());     // No need to scale, medianizer price is already 18 dec places
    }
}
