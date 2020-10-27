// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../mocks/MockWETH9.sol";
import "@nomiclabs/buidler/console.sol";

contract WETH9Fuzzing {

    MockWETH9 internal weth;

    constructor () public {
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