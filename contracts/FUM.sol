// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "erc20permit/contracts/ERC20Permit.sol";
import "./IUSM.sol";
import "./WithOptOut.sol";
import "./MinOut.sol";


/**
 * @title FUM Token
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 *
 * @notice This should be created and owned by the USM instance.
 */
contract FUM is ERC20Permit, WithOptOut {
    IUSM public immutable usm;

    constructor(address[] memory optedOut_)
        ERC20Permit("Minimalist Funding v1.0 - Test 4", "FUMTest")
        WithOptOut(optedOut_)
    {
        usm = IUSM(msg.sender);     // FUM constructor can only be called by a USM instance
    }

    /**
     * @notice If anyone sends ETH here, assume they intend it as a `fund`.  If decimals 8 to 11 (inclusive) of the amount of
     * ETH received are `0000`, then the next 7 will be parsed as the minimum number of FUM accepted per input ETH, with the
     * 7-digit number interpreted as "hundredths of a FUM".  See comments in `MinOut`.
     */
    receive() external payable {
        usm.fund{ value: msg.value }(msg.sender, MinOut.parseMinTokenOut(msg.value));
    }

    /**
     * @notice If a user sends FUM tokens directly to this contract (or to the USM contract), assume they intend it as a
     * `defund`.  If using `transfer`/`transferFrom` as `defund`, and if decimals 8 to 11 (inclusive) of the amount transferred
     * are `0000`, then the next 7 will be parsed as the maximum number of FUM tokens sent per ETH received, with the 7-digit
     * number interpreted as "hundredths of a FUM".  See comments in `MinOut`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override noOptOut(recipient) returns (bool) {
        if (recipient == address(this) || recipient == address(usm) || recipient == address(0)) {
            usm.defund(sender, payable(sender), amount, MinOut.parseMinEthOut(amount));
        } else {
            super._transfer(sender, recipient, amount);
        }
        return true;
    }

    /**
     * @notice Mint new FUM to the _recipient
     *
     * @param _recipient address to mint to
     * @param _amount amount to mint
     */
    function mint(address _recipient, uint _amount) external {
        require(msg.sender == address(usm), "Only USM");
        _mint(_recipient, _amount);
    }

    /**
     * @notice Burn FUM from _holder
     *
     * @param _holder address to burn from
     * @param _amount amount to burn
     */
    function burn(address _holder, uint _amount) external {
        require(msg.sender == address(usm), "Only USM");
        _burn(_holder, _amount);
    }
}
