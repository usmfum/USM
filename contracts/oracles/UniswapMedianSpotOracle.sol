// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./Oracle.sol";
import "./OurUniswap.sol";
import "./Median.sol";

contract UniswapMedianSpotOracle is Oracle {
    using SafeMath for uint;

    uint private constant NUM_SOURCE_ORACLES = 3;

    OurUniswap.Pair[NUM_SOURCE_ORACLES] private pairs;

    /**
     * See OurUniswapV2SpotOracle for example pairs to pass in.
     */
    constructor(IUniswapV2Pair[NUM_SOURCE_ORACLES] memory uniswapPairs,
                uint[NUM_SOURCE_ORACLES] memory tokens0Decimals,
                uint[NUM_SOURCE_ORACLES] memory tokens1Decimals,
                bool[NUM_SOURCE_ORACLES] memory tokensInReverseOrder) public
    {
        for (uint i = 0; i < NUM_SOURCE_ORACLES; ++i) {
            pairs[i] = OurUniswap.createPair(uniswapPairs[i], tokens0Decimals[i], tokens1Decimals[i], tokensInReverseOrder[i]);
        }
    }

    function latestPrice() public virtual override view returns (uint price) {
        price = latestUniswapMedianSpotPrice();
    }

    function latestUniswapMedianSpotPrice() public view returns (uint price) {
        // For maximum gas efficiency...
        price = Median.median(OurUniswap.spotPrice(pairs[0]),
                              OurUniswap.spotPrice(pairs[1]),
                              OurUniswap.spotPrice(pairs[2]));
    }

    function latestUniswapPair1SpotPrice() public view returns (uint price) {
        price = OurUniswap.spotPrice(pairs[0]);
    }

    function latestUniswapPair2SpotPrice() public view returns (uint price) {
        price = OurUniswap.spotPrice(pairs[1]);
    }

    function latestUniswapPair3SpotPrice() public view returns (uint price) {
        price = OurUniswap.spotPrice(pairs[2]);
    }
}
