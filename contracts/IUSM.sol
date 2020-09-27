// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;


interface IUSM {
    enum Side {Buy, Sell}

    event MinFumBuyPriceChanged(uint previous, uint latest);
    event MintBurnAdjustmentChanged(uint previous, uint latest);
    event FundDefundAdjustmentChanged(uint previous, uint latest);

    function mint(address from, address to, uint ethIn) external returns (uint);
    function burn(address from, address to, uint usmToBurn) external returns (uint);
    function fund(address from, address to, uint ethIn) external returns (uint);
    function defund(address from, address to, uint fumToBurn) external returns (uint);
    function ethPool() external view returns (uint);
    function ethBuffer() external view returns (int);
    function debtRatio() external view returns (uint);
    function usmPrice(Side side) external view returns (uint);
    function fumPrice(Side side) external view returns (uint);
    function minFumBuyPrice() external view returns (uint);
    function mintBurnAdjustment() external view returns (uint);
    function fundDefundAdjustment() external view returns (uint);
    function usmFromMint(uint ethIn) external view returns (uint, uint);
    function ethFromBurn(uint usmIn) external view returns (uint, uint);
    function fumFromFund(uint ethIn) external view returns (uint, uint);
    function ethFromDefund(uint fumIn) external view returns (uint, uint);
    function ethToUsm(uint ethAmount) external view returns (uint);
    function usmToEth(uint usmAmount) external view returns (uint);
}
