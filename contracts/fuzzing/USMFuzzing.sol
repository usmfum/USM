// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;
import "../IUSM.sol";
import "../USM.sol";
import "../FUM.sol";
import "../oracles/TestOracle.sol";
import "../mocks/MockWETH9.sol";
import "../WadMath.sol";
import "@nomiclabs/buidler/console.sol";

contract USMFuzzing {
    using WadMath for uint;

    USM internal usm;
    FUM internal fum;
    MockWETH9 internal weth;
    TestOracle internal oracle;

    constructor() public {
        weth = new MockWETH9();
        oracle = new TestOracle(25000000000, 8);
        usm = new USM(address(oracle), address(weth));
        fum = FUM(usm.fum());

        weth.approve(address(usm), uint(-1));
        usm.approve(address(usm), uint(-1));
        fum.approve(address(usm), uint(-1));
    }

    /// @dev Test minting USM increases the value of the system by the same amount as Eth provided, and that burning does the inverse.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testMintAndBurnEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        // A failing require aborts this test instance without failing the fuzzing
        require(ethIn >= 10**14); // I'm restricting tests to a range of inputs with this

        weth.mint(ethIn);

        uint valueBefore = weth.balanceOf(address(usm));
        uint usmOut = usm.mint(address(this), address(this), ethIn);
        uint valueMiddle = weth.balanceOf(address(usm));

        // The asserts are what we are testing. A failing assert will be reported.
        assert(valueBefore + ethIn == valueMiddle); // The value in eth of the USM supply increased by as much as the eth that went in

        uint ethOut = usm.burn(address(this), address(this), usmOut);
        uint valueAfter = weth.balanceOf(address(usm));

        assert(valueMiddle - ethOut == valueAfter); // The value in eth of the USM supply decreased by as much as the value in eth of the USM that was burnt
        assert(valueAfter >= valueBefore); // The protocol shouldn't have lost value with the round trip
    }

    /// @dev Test minting USM increases the value of the system by the same amount as Eth provided, and that burning does the inverse.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testFundAndDefundEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        require(ethIn >= 10**14); // 10**14 + 1 fails the last assertion

        weth.mint(ethIn);

        uint valueBefore = weth.balanceOf(address(usm));
        uint fumOut = usm.fund(address(this), address(this), ethIn);
        uint valueMiddle = weth.balanceOf(address(usm));

        assert(valueBefore + ethIn <= valueMiddle); // The value in eth of the FUM supply increased by as much as the eth that went in

        uint ethOut = usm.defund(address(this), address(this), fumOut);
        uint valueAfter = weth.balanceOf(address(usm));

        assert(valueMiddle - ethOut == valueAfter); // The value in eth of the FUM supply decreased by as much as the value in eth of the FUM that was burnt
        assert(valueAfter >= valueBefore); // The protocol shouldn't have lost value with the round trip
    }

    // Test that ethBuffer grows up with the fund/defund/mint/burn fee, plus minus eth for fund eth from defund
    // Test that with two consecutive ops, the second one gets a worse price
}