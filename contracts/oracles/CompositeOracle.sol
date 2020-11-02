// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

interface UniswapAnchoredView {
    function price(string calldata symbol) external view returns (uint);
}


contract CompositeOracle is IOracle, Ownable {
    using SafeMath for uint;

    AggregatorV3Interface public chainlinkOracle;
    uint public chainlinkShift;

    UniswapAnchoredView public compoundOracle;
    uint public compoundShift;

    IUniswapV2Pair public uniswapPair;
    bool public areTokensInReverseOrder;    // Whether to return reserve0 / reserve1, rather than reserve1 / reserve0
    uint public uniswapShift;
    uint public scalePriceBy;

    uint public override decimalShift;

    constructor(
        address chainlinkOracle_, uint chainlinkShift_,
        address compoundOracle_, uint compoundShift_,
        address uniswapPair_, bool areTokensInReverseOrder_, uint uniswapShift_, uint scalePriceBy_,
        uint decimalShift_
    )
        public
    {
        decimalShift = decimalShift_;

        chainlinkOracle = AggregatorV3Interface(chainlinkOracle_);
        chainlinkShift = 10 ** decimalShift.sub(chainlinkShift_);

        compoundOracle = UniswapAnchoredView(compoundOracle_);
        compoundShift = 10 ** decimalShift.sub(compoundShift_);

        uniswapPair = IUniswapV2Pair(uniswapPair_);
        areTokensInReverseOrder = areTokensInReverseOrder_;
        uniswapShift = 10 ** decimalShift.sub(uniswapShift_);
        scalePriceBy = scalePriceBy_;
    }

    function latestPrice()
        external override view returns (uint)
    {
        // For maximal gas efficiency...
        return median(chainlinkLatestPrice().mul(chainlinkShift),
                       compoundLatestPrice().mul(compoundShift),
                       uniswapLatestPrice().mul(uniswapShift)
                    );
    }

    function chainlinkLatestPrice() public view returns (uint) {
        (, int price,,,) = chainlinkOracle.latestRoundData();
        return uint(price); // TODO: Cast safely
    }

    function compoundLatestPrice() public view returns (uint) {
        // From https://compound.finance/docs/prices, also https://www.comp.xyz/t/open-price-feed-live/180
        return compoundOracle.price("ETH");
    }

    function uniswapLatestPrice() public view returns (uint) {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint112 reserve0, uint112 reserve1,) = uniswapPair.getReserves();
        (uint112 reserveA, uint112 reserveB) = areTokensInReverseOrder ? (reserve1, reserve0) : (reserve0, reserve1);
        return (uint(reserveB)).mul(scalePriceBy).div(uint(reserveA));      // See the "USDT * scalePriceBy / ETH" example above
    }

    function median(uint a, uint b, uint c)
        public pure returns (uint)
    {
        bool ab = a > b;
        bool bc = b > c;
        bool ca = c > a;

        return (ca == ab ? a : (ab == bc ? b : c));
    }
}