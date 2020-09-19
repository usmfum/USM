// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;


interface IUSM {
    enum Side {Buy, Sell}

    function mint(address from, address to, uint ethIn) external returns (uint);
    function burn(address from, address to, uint usmToBurn) external returns (uint);
    function fund(address from, address to, uint ethIn) external returns (uint);
    function defund(address from, address to, uint fumToBurn) external returns (uint);
    function ethPool() external view returns (uint);
    function ethBuffer() external view returns (int);
    function debtRatio() external view returns (uint);
    function fumPrice(Side side) external view returns (uint);
    function ethToUsm(uint ethAmount) external view returns (uint);
    function usmToEth(uint usmAmount) external view returns (uint);
}