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

    uint internal constant COMPOUND_SCALE_FACTOR = 10 ** 12; // Since Compound has 6 dec places, and latestPrice() needs 18

    UniswapAnchoredView public compoundView;

    constructor(address compoundView_) public
    {
        compoundView = UniswapAnchoredView(compoundView_);
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price) {
        price = compoundView.price("ETH").mul(COMPOUND_SCALE_FACTOR);
    }
}
