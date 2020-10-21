// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./IOracle.sol";
import "./IMakerPriceFeed.sol";

contract MakerOracle is IOracle {
    IMakerPriceFeed public medianizer;
    uint public override decimalShift;

    /**
     * @notice Mainnet details:
     * medianizer: 0x729D19f657BD0614b4985Cf1D82531c67569197B
     * decimalShift: 18
     */
    constructor(address medianizer_, uint decimalShift_) public {
        medianizer = IMakerPriceFeed(medianizer_);
        decimalShift = decimalShift_;
    }

    function latestPrice() external override view returns (uint) {
        // From https://studydefi.com/read-maker-medianizer/:
        return uint(medianizer.read());
    }
}
