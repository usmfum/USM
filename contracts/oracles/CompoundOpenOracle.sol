// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./IOracle.sol";
import "@nomiclabs/buidler/console.sol";


interface UniswapAnchoredView {
    function price(string calldata symbol) external view returns (uint);
}

contract CompoundOpenOracle is IOracle {
    UniswapAnchoredView public oracle;
    uint public override decimalShift;

    /**
     * @notice Mainnet details:
     * UniswapAnchoredView: 0x922018674c12a7f0d394ebeef9b58f186cde13c1
     * decimalShift: 6
     */
    constructor(address oracle_, uint decimalShift_) public {
        oracle = UniswapAnchoredView(oracle_);
        decimalShift = decimalShift_;
    }

    function latestPrice() external override view returns (uint) {
        // From https://compound.finance/docs/prices, also https://www.comp.xyz/t/open-price-feed-live/180
        return oracle.price("ETH");
    }

    // TODO: Remove for mainnet
    function latestPriceWithGas() external returns (uint256) {
        uint gas = gasleft();
        uint price = this.latestPrice();
        console.log("        compoundOracle.latestPrice() cost: ", gas - gasleft());
        return price;
    }
}
