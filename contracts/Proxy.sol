// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "./IUSM.sol";
import "./external/IWETH9.sol";


contract Proxy {
    using Address for address payable;
    IUSM public usm;
    IWETH9 public weth;

    constructor(address usm_, address weth_)
        public
    {
        usm = IUSM(usm_); 
        weth = IWETH9(weth_);

        weth.approve(address(usm), uint(-1));
    }

    // -------------------
    // Using Ether
    // -------------------

    /// @dev The WETH9 contract will send ether to Proxy on `weth.withdraw` using this function.
    receive() external payable { }

    /// @dev Users use `mint` in Proxy to post ETH to USM (amount = msg.value), which will be converted to Weth here.
    /// @param minUsmOut Minimum accepted USM for a successful mint.
    function mintWithEth(uint minUsmOut)
        external payable returns (uint)
    {
        weth.deposit{ value: msg.value }();
        uint usmOut = usm.mint(address(this), msg.sender, msg.value);
        require(usmOut >= minUsmOut, "Limit not reached");
        return usmOut;
    }

    /// @dev Users wishing to withdraw their Weth as ETH from USM should use this function.
    /// Users must have called `controller.addDelegate(Proxy.address)` to authorize Proxy to act in their behalf.
    /// @param usmToBurn Amount of USM to burn.
    /// @param minEthOut Minimum accepted ETH for a successful burn.
    function burnForEth(uint usmToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.burn(msg.sender, address(this), usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        weth.withdraw(ethOut);
        msg.sender.sendValue(ethOut);
        return ethOut;
    }

    /// @notice Funds the pool with ETH, converted to WETH
    /// @param minFumOut Minimum accepted FUM for a successful burn.
    function fundWithEth(uint minFumOut)
        external payable returns (uint)
    {
        weth.deposit{ value: msg.value }();
        uint fumOut = usm.fund(address(this), msg.sender, msg.value);
        require(fumOut >= minFumOut, "Limit not reached");
        return fumOut;
    }

    /// @notice Defunds the pool by sending FUM out in exchange for equivalent ETH from the pool
    /// @param fumToBurn Amount of FUM to burn.
    /// @param minEthOut Minimum accepted ETH for a successful defund.
    function defundForEth(uint fumToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.defund(msg.sender, address(this), fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        weth.withdraw(ethOut);
        msg.sender.sendValue(ethOut);
        return ethOut;
    }

    // -------------------
    // Using Wrapped Ether
    // -------------------

    /// @dev Users use `mint` in Proxy to post Weth to USM.
    /// @param ethIn Amount of wrapped eth to use for minting USM.
    /// @param minUsmOut Minimum accepted USM for a successful mint.
    function mint(uint ethIn, uint minUsmOut)
        external returns (uint)
    {
        uint usmOut = usm.mint(msg.sender, msg.sender, ethIn);
        require(usmOut >= minUsmOut, "Limit not reached");
        return usmOut;
    }

    /// @dev Users wishing to withdraw their Weth from USM should use this function.
    /// Users must have called `controller.addDelegate(Proxy.address)` to authorize Proxy to act in their behalf.
    /// @param usmToBurn Amount of USM to burn.
    /// @param minEthOut Minimum accepted WETH for a successful burn.
    function burn(uint usmToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.burn(msg.sender, msg.sender, usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        return ethOut;
    }

    /// @notice Funds the pool with WETH
    /// @param ethIn Amount of wrapped eth to use for minting FUM.
    /// @param minFumOut Minimum accepted FUM for a successful burn.
    function fund(uint ethIn, uint minFumOut)
        external returns (uint)
    {
        uint fumOut = usm.fund(msg.sender, msg.sender, ethIn); 
        require(fumOut >= minFumOut, "Limit not reached");
        return fumOut;
    }

    /// @notice Defunds the pool by sending FUM out in exchange for equivalent WETH from the pool
    /// @param fumToBurn Amount of FUM to burn.
    /// @param minEthOut Minimum accepted WETH for a successful defund.
    function defund(uint fumToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.defund(msg.sender, msg.sender, fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        return ethOut;
    }
}
