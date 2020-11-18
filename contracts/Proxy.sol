// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "./IUSM.sol";
import "./external/IWETH9.sol";

/**
 * @title USM Frontend Proxy
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 */
contract Proxy {
    enum EthType {ETH, WETH}

    using Address for address payable;

    IUSM public immutable usm;
    IWETH9 public immutable weth;

    constructor(address usm_, address weth_)
        public
    {
        usm = IUSM(usm_); 
        weth = IWETH9(weth_);
    }

    /// @dev The WETH9 contract will send ether to Proxy on `weth.withdraw` using this function.
    receive() external payable { }

    /// @dev Users use `mint()` in Proxy to input either WETH or ETH: either one results in passing WETH to `USM.mint()`.
    /// @param ethIn Amount of WETH/ETH to use for minting USM.
    /// @param minUsmOut Minimum accepted USM for a successful mint.
    /// @param inputType Whether the user passes in WETH, or ETH (which is immediately converted to WETH).
    function mint(uint ethIn, uint minUsmOut, EthType inputType)
        external payable returns (uint)
    {
        if (inputType == EthType.ETH) {
            require(msg.value == ethIn, "ETH input misspecified");
        } else {
            weth.transferFrom(msg.sender, address(this), ethIn);
            weth.withdraw(ethIn);
        }
        
        uint usmOut = usm.mint{ value: ethIn }(msg.sender, msg.sender);
        require(usmOut >= minUsmOut, "Limit not reached");
        return usmOut;
    }

    /// @dev Users wishing to withdraw their WETH from USM, either as WETH or as ETH, should use this function.
    /// Users must have called `controller.addDelegate(Proxy.address)` to authorize Proxy to act in their behalf.
    /// @param usmToBurn Amount of USM to burn.
    /// @param minEthOut Minimum accepted WETH/ETH for a successful burn.
    /// @param outputType Whether to send the user WETH, or first convert it to ETH.
    function burn(uint usmToBurn, uint minEthOut, EthType outputType)
        external returns (uint)
    {
        address payable receiver = (outputType == EthType.ETH ? msg.sender : address(this));
        uint ethOut = usm.burn(msg.sender, receiver, usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        if (outputType == EthType.WETH) {
            weth.deposit{ value: ethOut }();
            msg.sender.sendValue(ethOut);
        }
        return ethOut;
    }

    /// @notice Funds the pool either with WETH, or with ETH (then converted to WETH)
    /// @param ethIn Amount of WETH/ETH to use for minting FUM.
    /// @param minFumOut Minimum accepted FUM for a successful fund.
    /// @param inputType Whether the user passes in WETH, or ETH (which is immediately converted to WETH).
    function fund(uint ethIn, uint minFumOut, EthType inputType)
        external payable returns (uint)
    {
        if (inputType == EthType.ETH) {
            require(msg.value == ethIn, "ETH input misspecified");
        } else {
            weth.transferFrom(msg.sender, address(this), ethIn);
            weth.withdraw(ethIn);
        }
        uint fumOut = usm.fund{ value : ethIn }(msg.sender, msg.sender);
        require(fumOut >= minFumOut, "Limit not reached");
        return fumOut;
    }

    /// @notice Defunds the pool by redeeming FUM in exchange for equivalent WETH from the pool (optionally then converted to ETH)
    /// @param fumToBurn Amount of FUM to burn.
    /// @param minEthOut Minimum accepted WETH/ETH for a successful defund.
    /// @param outputType Whether to send the user WETH, or first convert it to ETH.
    function defund(uint fumToBurn, uint minEthOut, EthType outputType)
        external returns (uint)
    {
        address payable receiver = (outputType == EthType.ETH ? msg.sender : address(this));
        uint ethOut = usm.defund(msg.sender, receiver, fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        if (outputType == EthType.WETH) {
            weth.deposit{ value: ethOut }();
            msg.sender.sendValue(ethOut);
        }
        return ethOut;
    }
}
