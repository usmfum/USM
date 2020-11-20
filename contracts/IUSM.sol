// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

interface IUSM {
    function mint() external payable returns (uint);
    function mintTo(address to, uint minUsmOut) external payable returns (uint);
    function burn(uint usmToBurn) external returns (uint);
    function burnTo(address from, address payable to, uint usmToBurn, uint minEthOut) external returns (uint);
    function fund() external payable returns (uint);
    function fundTo(address to, uint minFumOut) external payable returns (uint);
    function defund(uint fumToBurn) external returns (uint);
    function defundTo(address from, address payable to, uint fumToBurn, uint minEthOut) external returns (uint);
}
