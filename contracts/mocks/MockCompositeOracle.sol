// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../oracles/CompositeOracle.sol";
import "@nomiclabs/buidler/console.sol";

contract MockCompositeOracle is CompositeOracle {

    constructor(IOracle[3] memory oracles_, uint decimalShift_) public CompositeOracle(oracles_, decimalShift_) { }

    function latestPriceWithGas() external returns (uint256) {
        uint gas = gasleft();
        uint price = this.latestPrice();
        console.log("        compositeOracle.latestPrice() cost: ", gas - gasleft());
        return price;
    }
}
