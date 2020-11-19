// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

interface IUSM {
    enum EthType {ETH, WETH}

    function mint() external payable returns (uint);
    function mint(address from, uint ethIn, EthType inputType, address to, uint minUsmOut) external payable returns (uint);
    function burn(uint usmToBurn) external returns (uint);
    function burn(address from, uint usmToBurn, address to, uint minEthOut, EthType outputType) external returns (uint);
    function fund() external payable returns (uint);
    function fund(address from, uint ethIn, EthType inputType, address to, uint minFumOut) external payable returns (uint);
    function defund(uint fumToBurn) external returns (uint);
    function defund(address from, uint fumToBurn, address to, uint minEthOut, EthType outputType) external returns (uint);
}
