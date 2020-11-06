// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "../oracles/Oracle.sol";

abstract contract SettableOracle is Oracle {
    function setPrice(uint price) public virtual;
}
