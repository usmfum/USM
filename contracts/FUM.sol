// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc20permit/contracts/ERC20Permit.sol";

/**
 * @title FUM Token
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 *
 * @notice This should be owned by the stablecoin.
 */
contract FUM is ERC20Permit, Ownable {

    address public usm;

    constructor(address usm_) public ERC20Permit("Minimal Funding", "FUM") {
        usm = usm_;
    }

    /**
     * @notice Regular transfer, disallowing transfers to this contract.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient != address(this) && recipient != address(usm), "Don't transfer here");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @notice Mint new FUM to the _recipient
     *
     * @param _recipient address to mint to
     * @param _amount amount to mint
     */
    function mint(address _recipient, uint _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    /**
     * @notice Burn FUM from _holder
     *
     * @param _holder address to burn from
     * @param _amount amount to burn
     */
    function burn(address _holder, uint _amount) external onlyOwner {
        _burn(_holder, _amount);
    }
}