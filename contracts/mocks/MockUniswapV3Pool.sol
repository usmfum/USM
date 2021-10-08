// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

//import "@uniswap/v3-core/contracts/libraries/Oracle.sol";
import "../oracles/uniswap/v3-core/Oracle.sol";
//import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../oracles/uniswap/v3-core/TickMath.sol";
//import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "../oracles/uniswap/v3-periphery/OracleLibrary.sol";

contract MockUniswapV3Pool {
    address public immutable token0 = address(1);     // Mimic USDC/ETH mainnet pool, where token0 < token1 (alphabetically)
    address public immutable token1 = address(2);

    uint16 public lastObservationIndex;

    mapping(uint => Oracle.Observation) public observations;

    function setObservation(uint16 observationIndex, uint32 blockTimestamp, int56 tickCumulative) public {
        observations[observationIndex] = Oracle.Observation(blockTimestamp, tickCumulative, 0, true);
        lastObservationIndex = observationIndex;
    }

    function slot0() public view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        //Oracle.Observation memory lastObservation = observations[lastObservationIndex];
        //tick = int24(lastObservation.tickCumulative);
        tick = OracleLibrary.consult(address(this), 1);     // 1 because any positive period should do here
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        return (sqrtPriceX96, tick, lastObservationIndex, 0, 0, 0, true);
    }

    /**
     * @notice See also
     * https://github.com/Uniswap/uniswap-v3-core/blob/main/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol, where
     * this fn is explained.  But for this crude stub, for the n inputs we just return the last n stored observation ticks.
     */
    function observe(uint32[] calldata secondsAgos) external view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);     // We leave this empty though
        for (uint16 i = 0; i < secondsAgos.length; ++i) {
            // secondsAgos must be in *decreasing* order, meaning, they must corresponding to *increasing* points in time:
            require(i == 0 || secondsAgos[i] <= secondsAgos[i - 1], "secondsAgos must be decreasing");
            // If, eg, the user passed in three secondsAgos [20, 10, 0], and we have ten stored observations [0..9], then we
            // want to return the most recent three observations, in chronological order - that is, observations [7, 8, 9]:
            uint16 observationIndex = lastObservationIndex - (uint16(secondsAgos.length - 1) - i);
            Oracle.Observation memory observation = observations[observationIndex];
            tickCumulatives[i] = observation.tickCumulative;
        }
    }
}
