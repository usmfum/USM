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
    using Address for address payable;
    IUSM public immutable usm;
    IWETH9 public immutable weth;

    constructor(IUSM usm_, IWETH9 weth_)
        public
    {
        usm = usm_;
        weth = weth_;
    }

    /**
     * @notice The USM contract's `burn`/`defund` functions will send ETH back to this contract, and the WETH9 contract will send
     * ETH here on `weth.withdraw` using this function.  If anyone else tries to send ETH here, reject it.
     */
    receive() external payable {
        require(msg.sender == address(usm) || msg.sender == address(weth), "Don't transfer here");
    }

    /**
     * @notice Accepts WETH, converts it to ETH, and passes it to `usm.mint`.
     * @param to address to send the minted USM to.
     * @param ethIn WETH to deduct.
     * @param minUsmOut Minimum accepted USM for a successful mint.
     */
    function mint(address to, uint ethIn, uint minUsmOut)
        external returns (uint usmOut)
    {
        require(weth.transferFrom(msg.sender, address(this), ethIn), "WETH transfer fail");
        weth.withdraw(ethIn);
        usmOut = usm.mint{ value: ethIn }(to, minUsmOut);
    }

    /**
     * @notice Burn USM in exchange for ETH, which is then converted to and returned as WETH.
     * @param to address to send the WETH to.
     * @param usmToBurn Amount of USM to burn.
     * @param minEthOut Minimum accepted WETH for a successful burn.
     */
    function burn(address to, uint usmToBurn, uint minEthOut)
        external returns (uint ethOut)
    {
        ethOut = usm.burn(msg.sender, address(this), usmToBurn, minEthOut);
        weth.deposit{ value: ethOut }();
        require(weth.transferFrom(address(this), to, ethOut), "WETH transfer fail");
    }

    /**
     * @notice Accepts WETH, converts it to ETH, and funds the pool by passing the ETH to `usm.fund`.
     * @param to address to send the minted FUM to.
     * @param ethIn WETH to deduct.
     * @param minFumOut Minimum accepted FUM for a successful mint.
     */
    function fund(address to, uint ethIn, uint minFumOut)
        external returns (uint fumOut)
    {
        require(weth.transferFrom(msg.sender, address(this), ethIn), "WETH transfer fail");
        weth.withdraw(ethIn);
        fumOut = usm.fund{ value: ethIn }(to, minFumOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool, which is then converted to and
     * returned as WETH.
     * @param to address to send the WETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defund(address to, uint fumToBurn, uint minEthOut)
        external returns (uint ethOut)
    {
        ethOut = usm.defund(msg.sender, address(this), fumToBurn, minEthOut);
        weth.deposit{ value: ethOut }();
        require(weth.transferFrom(address(this), to, ethOut), "WETH transfer fail");
    }
}
