// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Oracle.sol";

interface UniswapAnchoredView {
    function price(string calldata symbol) external view returns (uint);
}

/**
 * @title CompoundOpenOracle
 */
contract CompoundOpenOracle is Oracle {
    using SafeMath for uint;

    uint private constant SCALE_FACTOR = 10 ** 12;      // Since Compound has 6 dec places, and latestPrice() needs 18

    uint private constant UINT32_MAX = 2 ** 32 - 1;     // Should really be type(uint32).max, but that needs Solidity 0.6.8...
    uint private constant UINT224_MAX = 2 ** 224 - 1;   // Ditto, type(uint224).max

    struct TimedPrice {
        uint32 updateTime;
        uint224 price;
    }

    UniswapAnchoredView public anchoredView;
    TimedPrice public storedCompoundPrice;

    constructor(UniswapAnchoredView anchoredView_) public
    {
        anchoredView = anchoredView_;
    }

    function refreshPrice() public virtual override returns (uint price, uint updateTime) {
        price = anchoredView.price("ETH").mul(SCALE_FACTOR);
        if (price != storedCompoundPrice.price) {
            require(now <= UINT32_MAX, "timestamp overflow");
            require(price <= UINT224_MAX, "price overflow");
            (storedCompoundPrice.updateTime, storedCompoundPrice.price) = (uint32(now), uint224(price));
        }
        return (price, storedCompoundPrice.updateTime);
    }

    /**
     * @notice This returns the latest price retrieved and cached by `refreshPrice()`.  This function doesn't actually
     * retrieve the latest price, because as a view function, it (annoyingly) has no way to update updateTime, and (also
     * annoyingly) Compound's UniswapAnchoredView stores but doesn't expose the updateTime of the price it returns.
     */
    function latestPrice() public virtual override view returns (uint price, uint updateTime) {
        (price, updateTime) = (storedCompoundPrice.price, storedCompoundPrice.updateTime);
    }

    function latestCompoundPrice() public view returns (uint price, uint updateTime) {
        (price, updateTime) = (storedCompoundPrice.price, storedCompoundPrice.updateTime);
    }
}
