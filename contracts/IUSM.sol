// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "acc-erc20/contracts/IERC20.sol";
import "./WadMath.sol";

abstract contract IUSM is IERC20 {
    enum Side {Buy, Sell}

    function mint(address to, uint minUsmOut) external virtual payable returns (uint);
    function burn(address from, address payable to, uint usmToBurn, uint minEthOut) external virtual returns (uint);
    function fund(address to, uint minFumOut) external virtual payable returns (uint);
    function defund(address from, address payable to, uint fumToBurn, uint minEthOut) external virtual returns (uint);

    function refreshPrice() public virtual returns (uint price, uint updateTime);

    function latestPrice() public virtual view returns (uint price, uint updateTime);
    function latestOraclePrice() public virtual view returns (uint price, uint updateTime);
    function ethPool() public virtual view returns (uint pool);
    function fumTotalSupply() public virtual view returns (uint supply);
    function bidAskAdjustment() public virtual view returns (uint adjustment);
    function timeSystemWentUnderwater() public virtual view returns (uint timestamp);

    function ethBuffer(uint ethUsdPrice, uint ethInPool, uint usmSupply, WadMath.Round upOrDown) public virtual pure returns (int buffer);
    function debtRatio(uint ethUsdPrice, uint ethInPool, uint usmSupply) public virtual pure returns (uint ratio);
    function ethToUsm(uint ethUsdPrice, uint ethAmount, WadMath.Round upOrDown) public virtual pure returns (uint usmOut);
    function usmToEth(uint ethUsdPrice, uint usmAmount, WadMath.Round upOrDown) public virtual pure returns (uint ethOut);
    function adjustedEthUsdPrice(Side side, uint ethUsdPrice, uint debtRatio_) public virtual pure returns (uint price);
    function usmPrice(Side side, uint adjustedEthUsdPrice_) public virtual pure returns (uint price);
    function fumPrice(Side side, uint adjustedEthUsdPrice_, uint ethInPool, uint usmEffectiveSupply, uint fumSupply) public virtual pure returns (uint price);
    function checkIfUnderwater(uint usmActualSupply, uint ethPool_, uint ethUsdPrice, uint oldTimeUnderwater, uint currentTime) public virtual pure returns (uint timeSystemWentUnderwater_, uint usmSupplyForFumBuys, uint debtRatio_);
}
