// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

contract MockCompoundUniswapAnchoredView {
    uint public _price;

    function set(uint value) external {
        _price = value;
    }

    function price(string calldata) external view returns(uint256) {
        return _price;
    }
}
