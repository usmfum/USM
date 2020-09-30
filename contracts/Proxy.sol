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
    /// @param to Receiver of the minted USM
    /// @param minUsmOut Minimum accepted USM for a successful mint.
    function mintWithEth(address to, uint minUsmOut)
        external payable returns (uint)
    {
        weth.deposit{ value: msg.value }();
        uint usmOut = usm.mint(address(this), to, msg.value);
        require(usmOut >= minUsmOut, "Limit not reached");
        return usmOut;
    }

    /// @dev Users wishing to withdraw their Weth as ETH from USM should use this function.
    /// Users must have called `controller.addDelegate(Proxy.address)` to authorize Proxy to act in their behalf.
    /// @param to Receiver of the obtained ETH
    /// @param usmToBurn Amount of USM to burn.
    /// @param minEthOut Minimum accepted ETH for a successful burn.
    function burnForEth(address payable to, uint usmToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.burn(msg.sender, address(this), usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        weth.withdraw(ethOut);
        to.sendValue(ethOut);
        return ethOut;
    }

    /// @notice Funds the pool with ETH, converted to WETH
    /// @param to Receiver of the obtained FUM
    /// @param minFumOut Minimum accepted FUM for a successful burn.
    function fundWithEth(address to, uint minFumOut)
        external payable returns (uint)
    {
        weth.deposit{ value: msg.value }();
        uint fumOut = usm.fund(address(this), to, msg.value);
        require(fumOut >= minFumOut, "Limit not reached");
        return fumOut;
    }

    /// @notice Defunds the pool by sending FUM out in exchange for equivalent ETH from the pool
    /// @param to Receiver of the obtained ETH
    /// @param fumToBurn Amount of FUM to burn.
    /// @param minEthOut Minimum accepted ETH for a successful defund.
    function defundForEth(address payable to, uint fumToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.defund(msg.sender, address(this), fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        weth.withdraw(ethOut);
        to.sendValue(ethOut);
        return ethOut;
    }

    // -------------------
    // Using Wrapped Ether
    // -------------------

    /// @dev Users use `mint` in Proxy to post Weth to USM.
    /// @param to Receiver of the minted USM
    /// @param ethIn Amount of wrapped eth to use for minting USM.
    /// @param minUsmOut Minimum accepted USM for a successful mint.
    function mint(address to, uint ethIn, uint minUsmOut)
        external returns (uint)
    {
        uint usmOut = usm.mint(msg.sender, to, ethIn);
        require(usmOut >= minUsmOut, "Limit not reached");
        return usmOut;
    }

    /// @dev Users wishing to withdraw their Weth from USM should use this function.
    /// Users must have called `controller.addDelegate(Proxy.address)` to authorize Proxy to act in their behalf.
    /// @param to Receiver of the obtained wrapped ETH
    /// @param usmToBurn Amount of USM to burn.
    /// @param minEthOut Minimum accepted WETH for a successful burn.
    function burn(address to, uint usmToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.burn(msg.sender, to, usmToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        return ethOut;
    }

    /// @notice Funds the pool with WETH
    /// @param to Receiver of the obtained FUM
    /// @param ethIn Amount of wrapped eth to use for minting FUM.
    /// @param minFumOut Minimum accepted FUM for a successful burn.
    function fund(address to, uint ethIn, uint minFumOut)
        external returns (uint)
    {
        uint fumOut = usm.fund(msg.sender, to, ethIn); 
        require(fumOut >= minFumOut, "Limit not reached");
        return fumOut;
    }

    /// @notice Defunds the pool by sending FUM out in exchange for equivalent WETH from the pool
    /// @param to Receiver of the obtained ETH
    /// @param fumToBurn Amount of FUM to burn.
    /// @param minEthOut Minimum accepted WETH for a successful defund.
    function defund(address to, uint fumToBurn, uint minEthOut)
        external returns (uint)
    {
        uint ethOut = usm.defund(msg.sender, to, fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");
        return ethOut;
    }
}
