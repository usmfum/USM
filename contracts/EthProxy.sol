// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "./IUSM.sol";
import "./external/IWETH9.sol";


contract EthProxy {
    IUSM public usm;
    IWETH9 public weth;

    constructor(address usm_, address weth_) public {
        usm = IUSM(usm_); 
        weth = IWETH9(weth_);

        weth.approve(address(usm), uint(-1));
    }

    /// @dev The WETH9 contract will send ether to EthProxy on `weth.withdraw` using this function.
    receive() external payable { }

    /// @dev Users use `mint` in EthProxy to post ETH to USM (amount = msg.value), which will be converted to Weth here.
    /// @param to Receiver of the minted USM
    function mint(address to)
        external payable {
        weth.deposit{ value: msg.value }();
        usm.mint(address(this), to, msg.value);
    }

    /// @dev Users wishing to withdraw their Weth as ETH from USM should use this function.
    /// Users must have called `controller.addDelegate(ethProxy.address)` to authorize EthProxy to act in their behalf.
    /// @param to Receiver of the obtained Eth
    /// @param usmToBurn Amount of USM to burn.
    function burn(address payable to, uint usmToBurn)
        external {
        uint wethToWithdraw = usm.burn(msg.sender, address(this), usmToBurn);
        weth.withdraw(wethToWithdraw);
        to.transfer(wethToWithdraw);
    }

    /**
     * @notice Funds the pool with ETH, converted to WETH
     * @param to Receiver of the obtained FUM
     */
    function fund(address to)
        external payable
    {
        weth.deposit{ value: msg.value }();
        usm.fund(address(this), to, msg.value);
    }

    /**
     * @notice Defunds the pool by sending FUM out in exchange for equivalent ETH from the pool
     * @param to Receiver of the obtained ETH
     * @param fumToBurn Amount of FUM to burn.
     */
    function defund(address payable to, uint fumToBurn)
        external
    {
        uint wethToWithdraw = usm.defund(msg.sender, address(this), fumToBurn);
        weth.withdraw(wethToWithdraw);
        to.transfer(wethToWithdraw);
    }
}
