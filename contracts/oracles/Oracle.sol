// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

abstract contract Oracle {
    function latestPrice() public virtual view returns (uint price);    // Prices must be WAD-scaled - 18 decimal places

    /**
     * @dev This pure virtual implementation, which is intended to be (optionally) overridden by stateful implementations,
     * confuses solhint into giving a "Function state mutability can be restricted to view" warning.  Unfortunately there seems
     * to be no elegant/gas-free workaround as yet: see https://github.com/ethereum/solidity/issues/3529.
     */
    function cacheLatestPrice() public virtual returns (uint price) {
        price = latestPrice();  // Default implementation doesn't do any cacheing, just returns price.  But override as needed
    }
}
