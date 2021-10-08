// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../mocks/MockWETH9.sol";
import "hardhat/console.sol";

contract WETH9Fuzzing {

    MockWETH9 internal immutable weth;

    constructor () {
        weth = new MockWETH9();
    }

    function fuzzMint(uint ethAmount) public {
        uint supply = weth.totalSupply();
        uint balance = weth.balanceOf(address(this));
        weth.mint(ethAmount);
        assert(weth.totalSupply() == supply); // Since `mint` is a hack, t doesn't change the supply
        assert(weth.balanceOf(address(this)) == balance + ethAmount);
    }
}
