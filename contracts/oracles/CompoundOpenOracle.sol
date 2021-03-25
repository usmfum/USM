// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "./CompoundUniswapAnchoredView.sol";

/**
 * @title CompoundOpenOracle
 */
contract CompoundOpenOracle is Oracle {

    uint public constant COMPOUND_SCALE_FACTOR = 1e12;  // Since Compound has 6 dec places, and latestPrice() needs 18

    struct TimedPrice {
        uint32 updateTime;
        uint224 price;      // Standard WAD-scaled price
    }

    CompoundUniswapAnchoredView public immutable compoundUniswapAnchoredView;
    TimedPrice public compoundStoredPrice;

    constructor(CompoundUniswapAnchoredView anchoredView)
    {
        compoundUniswapAnchoredView = anchoredView;
    }

    function refreshPrice() public virtual override returns (uint price, uint updateTime) {
        price = compoundUniswapAnchoredView.price("ETH") * COMPOUND_SCALE_FACTOR;
        if (price != compoundStoredPrice.price) {
            updateTime = block.timestamp;
            require(updateTime <= type(uint32).max, "timestamp overflow");
            require(price <= type(uint224).max, "price overflow");
            (compoundStoredPrice.updateTime, compoundStoredPrice.price) = (uint32(updateTime), uint224(price));
        } else {
            updateTime = compoundStoredPrice.updateTime;
        }
    }

    /**
     * @notice This returns the latest price retrieved and cached by `refreshPrice()`.  This function doesn't actually
     * retrieve the latest price, because as a view function, it (annoyingly) has no way to update updateTime, and (also
     * annoyingly) CompoundUniswapAnchoredView stores but doesn't expose the updateTime of the price it returns.
     */
    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime) = (compoundStoredPrice.price, compoundStoredPrice.updateTime);
        //require(updateTime > 0, "Price not set yet");
    }

    function latestCompoundPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = (compoundStoredPrice.price, compoundStoredPrice.updateTime);
        //require(updateTime > 0, "Price not set yet");
    }
}
