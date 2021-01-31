// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "erc20permit/contracts/ERC20Permit.sol";

abstract contract ERC20WithBlacklist is ERC20Permit {
    mapping(address => bool) public blacklist;  // true = address is blacklisted (typically, has blacklisted itself)

    constructor(address[] memory initialBlacklist) public {
        for (uint i = 0; i < initialBlacklist.length; ++i) {
            blacklist[initialBlacklist[i]] = true;
        }
    }

    function addCallerToBlacklist() public virtual {
        blacklist[msg.sender] = true;
    }

    function removeCallerFromBlacklist() public virtual {
        blacklist[msg.sender] = false;
    }

    function addToBlacklist(address recipient) internal virtual {
        blacklist[recipient] = true;
    }

    function removeFromBlacklist(address recipient) internal virtual {
        blacklist[recipient] = false;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(!blacklist[recipient], "Invalid recipient");
        super._transfer(sender, recipient, amount);
    }
}
