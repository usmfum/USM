// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../oracles/CompositeOracle.sol";

contract MockCompositeOracle is CompositeOracle {

    constructor(IOracle[] memory oracles_, uint decimalShift_) public CompositeOracle(oracles_, decimalShift_) { }

    function latestPriceWithGas() external returns (uint256) {
        return this.latestPrice();
    }
}
