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

    constructor(IMakerPriceFeed medianizer_) public
    {
        medianizer = medianizer_;
    }

    function latestPrice() public virtual override view returns (uint price) {
        price = latestMakerPrice();
    }

    function latestMakerPrice() public view returns (uint price) {
        // From https://studydefi.com/read-maker-medianizer/:
        price = uint(medianizer.read());    // No need to scale, medianizer price is already 18 dec places
    }
}
