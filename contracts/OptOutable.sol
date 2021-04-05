// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


/**
 * A general type of contract with a behavior that using contracts can "opt out of".  The practical motivation is, when we have
 * multiple versions of a token (eg, USMv1 and USMv2), and support "mint/burn via send" - sending ETH/tokens mints/burns tokens
 * (respectively), there's a UX risk that users might accidentally send (eg) USMv1 tokens to the USMv2 address: resulting in
 * not a burn (returning ETH), but just the tokens being permanently lost with no ETH sent back in exchange.
 *
 * To avoid this, we want the USMv1 contract to be able to "opt out" of receiving USMv2 tokens, and vice versa:
 *
 *     1. During creation of USMv2, the address of USMv1 is included in the `optedOut_` argument to the USMv2 constructor.
 *     2. This puts USMv1 in USMv2's `optedOut` state variable.
 *     3. Then, if someone accidentally tries to send USMv1 tokens to the USMv2 address, the `_transfer()` call fails, rather
 *        than the USMv1 tokens being permanently lost.
 *     4. And to handle the reverse case, USMv2's constructor can call `USMv1.optOut()`, so that sends of USMv2 tokens to the
 *        USMv1 address also fail cleanly.  (USMv2 couldn't be passed to USMv1's constructor, because USMv2 didn't exist yet!)
 *
 * See also https://github.com/usmfum/USM/issues/88 and https://github.com/usmfum/USM/pull/93.
 *
 * Note that this would be prone to abuse if users could call `optOut()` on *other* contracts: so we only let a contract opt
 * *itself* out, ie, `optOut()` takes no argument.  (Or it could be passed to the constructor of the `OptOutable`-implementing
 * contract.)
 */
abstract contract OptOutable {
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
