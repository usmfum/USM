// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IUSM.sol";

/**
 * @title USM view-only proxy
 * @author Alberto Cuesta Cañada, Jacob Eliosoff, Alex Roan
 */
contract USMView {
    IUSM public immutable usm;

    constructor(IUSM usm_)
    {
        usm = usm_;
    }

    // ____________________ External informational view functions ____________________

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(WadMath.Round upOrDown) external view returns (int buffer) {
        (uint price, ) = usm.latestPrice();
        buffer = usm.ethBuffer(price, usm.ethPool(), usm.usmTotalSupply(), upOrDown);
    }

    /**
     * @notice Convert ETH amount to USM using the latest oracle ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethAmount, WadMath.Round upOrDown) external view returns (uint usmOut) {
        (uint price, ) = usm.latestPrice();
        usmOut = usm.ethToUsm(price, ethAmount, upOrDown);
    }

    /**
     * @notice Convert USM amount to ETH using the latest oracle ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint usmAmount, WadMath.Round upOrDown) external view returns (uint ethOut) {
        (uint price, ) = usm.latestPrice();
        ethOut = usm.usmToEth(price, usmAmount, upOrDown);
    }

    /**
     * @notice Calculate debt ratio.
     * @return ratio Debt ratio
     */
    function debtRatio() external view returns (uint ratio) {
        (uint price, ) = usm.latestPrice();
        ratio = usm.debtRatio(price, usm.ethPool(), usm.usmTotalSupply());
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms) - that is, of the next unit, before price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(IUSM.Side side) external view returns (uint price) {
        (uint ethUsdPrice, ) = usm.latestPrice();
        price = usm.usmPrice(side, ethUsdPrice, usm.buySellAdjustment());
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms) - that is, of the next unit, before price start sliding.
     * @return price FUM price in ETH terms
     */
    function fumPrice(IUSM.Side side) external view returns (uint price) {
        (uint ethUsdPrice, ) = usm.latestPrice();
        uint ethPool_ = usm.ethPool();
        uint usmSupply = usm.usmTotalSupply();
        uint oldTimeUnderwater = usm.timeSystemWentUnderwater();
        if (side == IUSM.Side.Buy) {
            (, usmSupply) = usm.checkIfUnderwater(usmSupply, ethPool_, ethUsdPrice, oldTimeUnderwater);
        }
        price = usm.fumPrice(side, ethUsdPrice, ethPool_, usmSupply, usm.fumTotalSupply(), usm.buySellAdjustment());
    }
}
