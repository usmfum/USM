// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


abstract contract WithOptOut {
    event OptOutStatusChanged(address indexed user, bool newStatus);

    mapping(address => bool) public optedOut;  // true = address opted out of something

    constructor(address[] memory optedOut_) {
        for (uint i = 0; i < optedOut_.length; i++) {
            optedOut[optedOut_[i]] = true;
        }
    }

    modifier noOptOut(address target) {
        require(!optedOut[target], "Target opted out");
        _;
    }

    function optOut() public virtual {
        if (!optedOut[msg.sender]) {
            optedOut[msg.sender] = true;
            emit OptOutStatusChanged(msg.sender, true);
        }
    }

    function optBackIn() public virtual {
        if (optedOut[msg.sender]) {
            optedOut[msg.sender] = false;
            emit OptOutStatusChanged(msg.sender, false);
        }
    }
}
