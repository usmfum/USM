// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;


interface IUSM {
    function mint(address from, address to, uint ethIn) external returns (uint);
    function burn(address from, address to, uint usmToBurn) external returns (uint);
    function fund(address from, address to, uint ethIn) external returns (uint);
    function defund(address from, address to, uint fumToBurn) external returns (uint);
}
