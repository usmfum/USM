// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

abstract contract Oracle {
    function latestPrice() public virtual view returns (uint price, uint updateTime);    // Prices WAD-scaled - 18 dec places

    /**
     * @dev This pure virtual implementation, which is intended to be (optionally) overridden by stateful implementations,
     * confuses solhint into giving a "Function state mutability can be restricted to view" warning.  Unfortunately there seems
     * to be no elegant/gas-free workaround as yet: see https://github.com/ethereum/solidity/issues/3529.
     */
    function refreshPrice() public virtual returns (uint price, uint updateTime) {
        (price, updateTime) = latestPrice();    // Default implementation doesn't do any cacheing.  But override as needed
    }
}
