// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "erc20permit/contracts/ERC20Permit.sol";


contract ERC20WithOptOut is ERC20Permit {
    mapping(address => bool) public optedOut;  // true = address opted out of something

    constructor(string memory name_, string memory symbol_) public ERC20Permit(name_, symbol_) {}

    modifier noOptOut(address target) {
        require(!optedOut[target], "Target opted out");
        _;
    }

    function optOut() public virtual {
        optedOut[msg.sender] = true;
    }

    function optBackIn() public virtual {
        optedOut[msg.sender] = false;
    }
}
