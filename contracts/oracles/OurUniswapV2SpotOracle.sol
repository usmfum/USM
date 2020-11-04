// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./Median.sol";

contract OurUniswapV2SpotOracle is Oracle {
    using SafeMath for uint;

    struct UniswapPriceablePair {
        IUniswapV2Pair pair;
        bool tokensInReverseOrder;
        uint scaleFactor;
    }

    UniswapPriceablePair private pair;

    /**
     *  Example pairs to pass in:
     *  ETH/USDT: 0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852, false, 10 ** 30 (since ETH/USDT has -12 dec places, and we want 18)
     *  USDC/ETH: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc, true, 10 ** 6 (since USDC/ETH has 12 dec places, and we want 18)
     *  DAI/ETH: 0xa478c2975ab1ea89e8196811f51a7b7ade33eb11, true, 10 ** 18 (since DAI/ETH has 0 dec places, and we want 18)
     */
    constructor(address pair_, bool tokensInReverseOrder, uint scaleFactor) public {
        pair = UniswapPriceablePair(IUniswapV2Pair(pair_), tokensInReverseOrder, scaleFactor);
    }

    function latestPrice() public virtual override view returns (uint price) {
        // Modeled off of https://github.com/anydotcrypto/uniswap-v2-periphery/blob/64dcf659928f9b9f002fdb58b4c655a099991472/contracts/UniswapV2Router04.sol -
        // thanks @stonecoldpat for the tip.
        (uint112 reserve0, uint112 reserve1,) = pair.pair.getReserves();
        (uint112 reserveA, uint112 reserveB) = pair.tokensInReverseOrder ? (reserve1, reserve0) : (reserve0, reserve1);
        price = (uint(reserveB)).mul(pair.scaleFactor).div(uint(reserveA));
    }
}
