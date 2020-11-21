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
     */
    receive() external payable {
        usm.fundTo{ value: msg.value }(msg.sender, MinOut.inferMinTokenOut(msg.value));
    }

    /**
     * @notice If a user sends FUM tokens directly to this contract (or to the USM contract), assume they intend it as a `defund`.
     * @return success Transfer success
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool success) {
        if (recipient == address(this) || recipient == address(usm)) {
            usm.defundFromFUM(_msgSender(), _msgSender(), amount);
        } else {
            _transfer(_msgSender(), recipient, amount);
        }
        success = true;
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
