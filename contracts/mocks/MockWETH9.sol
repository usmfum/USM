// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "../external/WETH9.sol";


contract MockWETH9 is WETH9 {

    function mint(uint amount) public {
        balanceOf[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
}