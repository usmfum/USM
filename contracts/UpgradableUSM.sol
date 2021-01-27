// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./USM.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./oracles/Oracle.sol";

contract UpgradableUSM is USM, Ownable {
    using Address for address;
    using Address for address payable;

    address public upgradeAddress;
    address public proposedUpgradeAddress;

    event UpgradeAddressProposed(address indexed previousProposal, address indexed newProposal);
    event UpgradeAddressConfirmed(address indexed upgradeAddress);

    constructor(Oracle oracle_) public USM(oracle_) {}

    /**
     * @notice Propose an upgrade address.
     * @dev Must be a contract address, callable only by owner and callable only if the
     * upgradeAddress is not already set 
     * @param proposed address
     */
    function proposeUpgradeAddress(address proposed) external onlyOwner upgradeAddressNotSet {
        require(proposed.isContract(), "Must be contract");
        address priorProposal = proposedUpgradeAddress;
        proposedUpgradeAddress = proposed;
        emit UpgradeAddressProposed(priorProposal, proposed);
    }

    /**
     * @notice Confirm the currently proposedUpgradeAddress as the upgradeAddress/
     * @dev THIS CAN ONLY BE DONE ONCE. Only callable by owner and upgradeAddress must not already
     * be set.
     * @param confirmed address to confirm
     */
    function confirmUpgradeAddress(address confirmed) external onlyOwner upgradeAddressNotSet {
        require(proposedUpgradeAddress == confirmed, "Does not match proposed");
        upgradeAddress = proposedUpgradeAddress;
        emit UpgradeAddressConfirmed(upgradeAddress);
    }

    /**
     * @notice Request to swap all old tokens owned by the holder to new upgrade tokens
     * @dev This must be called by the upgrade address
     * @param holder address
     * @return success - This determines whether or not the upgrade contract mints new tokens to the holder
     */
    function requestSwap(address holder) external upgrading onlyUpgradeAddress returns (bool){
        uint tokenBalance = balanceOf(holder);
        require(tokenBalance > 0, "Holder has no tokens to swap");
        (uint price,,,) = _refreshPrice();
        uint ethAmount = tokenBalance.wadDivDown(price);
        require(address(this).balance >= ethAmount, "Not enough ether");
        _burn(holder, tokenBalance);
        payable(upgradeAddress).sendValue(ethAmount);
        return true;
    }

    modifier upgrading() {
        require(upgradeAddress != address(0), "Not currently upgrading");
        _;
    }

    modifier upgradeAddressNotSet() {
        require(upgradeAddress == address(0), "Upgrade address already set");
        _;
    }

    modifier onlyUpgradeAddress() {
        require(msg.sender == upgradeAddress, "Must be upgrade address");
        _;
    }
}
