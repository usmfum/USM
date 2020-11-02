// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "../USM.sol";

/**
 * @title MockWadMath
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice This contract gives access to the internal functions of WadMath for testing
 */
contract MockUSM is USM {
    uint private savedPrice;

    constructor(address eth_, address chainlinkOracle_, address compoundOracle_,
                address uniswapEthUsdtPair_, bool uniswapEthUsdtPairInReverseOrder_,
                address uniswapUsdcEthPair_, bool uniswapUsdcEthPairInReverseOrder_,
                address uniswapDaiEthPair_, bool uniswapDaiEthPairInReverseOrder_) public
        USM(eth_, chainlinkOracle_, compoundOracle_, uniswapEthUsdtPair_, uniswapEthUsdtPairInReverseOrder_,
            uniswapUsdcEthPair_, uniswapUsdcEthPairInReverseOrder_, uniswapDaiEthPair_, uniswapDaiEthPairInReverseOrder_) {}

    function setPrice(uint p) public {
        savedPrice = p;
    }

    function oraclePrice() public override view returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : super.oraclePrice();
    }
}
