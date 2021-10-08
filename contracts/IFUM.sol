// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "acc-erc20/contracts/IERC20.sol";

interface IFUM is IERC20 {
    /**
     * @notice Mint new FUM to the _recipient
     *
     * @param _recipient address to mint to
     * @param _amount amount to mint
     */
    function mint(address _recipient, uint _amount) external;
    /**
     * @notice Burn FUM from _holder
     *
     * @param _holder address to burn from
     * @param _amount amount to burn
     */
    function burn(address _holder, uint _amount) external;
}
