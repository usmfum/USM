// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./MinOut.sol";

/**
 * @title FUM Token
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 *
 * @notice This should be owned by the stablecoin.
 */
contract FUM is ERC20Permit, Ownable {
    IUSM public immutable usm;

    constructor(IUSM usm_) public ERC20Permit("Minimal Funding", "FUM") {
        usm = usm_;
    }

    /**
     * @notice If anyone sends ETH here, assume they intend it as a `fund`.
     * If decimals 8 to 11 (included) of the amount of Ether received are `0000` then the next 7 will
     * be parsed as the minimum Ether price accepted, with 2 digits before and 5 digits after the comma. 
     */
    receive() external payable {
        usm.fund{ value: msg.value }(msg.sender, MinOut.parseMinTokenOut(msg.value));
    }

    /**
     * @notice If a user sends FUM tokens directly to this contract (or to the USM contract), assume they intend it as a `defund`.
     * If using `transfer`/`transferFrom` as `defund, and if decimals 8 to 11 (included) of the amount transferred received
     * are `0000` then the next 7 will be parsed as the maximum FUM price accepted, with 5 digits before and 2 digits after the comma.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        if (recipient == address(this) || recipient == address(usm) || recipient == address(0)) {
            usm.defundFromFUM(sender, payable(sender), amount, MinOut.parseMinEthOut(amount));
        } else {
            super._transfer(sender, recipient, amount);
        }
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
