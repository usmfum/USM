// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;
import "../IUSM.sol";
import "../USM.sol";
import "../FUM.sol";
import "../oracles/TestOracle.sol";
import "../mocks/MockWETH9.sol";
import "../WadMath.sol";
import "@nomiclabs/buidler/console.sol";


/**
 * This fuzzing contract tests that USM.sol moves Eth between itself and the clients accordingly to the parameters and return values of mint, burn, fund and defund.
 */
contract USMFuzzingEthMgmt {
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

    /// @dev Test that USM.sol takes eth when minting.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testMintEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        // A failing require aborts this test instance without failing the fuzzing
        require(ethIn >= 10**14); // I'm restricting tests to a range of inputs with this

        weth.mint(ethIn);

        uint valueBefore = weth.balanceOf(address(usm));
        usm.mint(address(this), address(this), ethIn);
        uint valueAfter = weth.balanceOf(address(usm));

        // The asserts are what we are testing. A failing assert will be reported.
        assert(valueBefore + ethIn == valueAfter); // The value in eth of the USM supply increased by as much as the eth that went in
    }

    /// @dev Test that USM.sol returns eth when burning.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testBurnEthValue(uint usmOut) public { // To exclude a function from testing, make it internal
        // A failing require aborts this test instance without failing the fuzzing
        require(usmOut >= 10**14); // I'm restricting tests to a range of inputs with this

        uint valueBefore = weth.balanceOf(address(usm));
        uint ethOut = usm.burn(address(this), address(this), usmOut);
        uint valueAfter = weth.balanceOf(address(usm));

        assert(valueBefore - ethOut == valueAfter); // The value in eth of the USM supply decreased by as much as the value in eth of the USM that was burnt
    }

    /// @dev Test that USM.sol takes eth when funding.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testFundEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        require(ethIn >= 10**14); // 10**14 + 1 fails the last assertion

        weth.mint(ethIn);

        uint valueBefore = weth.balanceOf(address(usm));
        usm.fund(address(this), address(this), ethIn);
        uint valueAfter = weth.balanceOf(address(usm));

        assert(valueBefore + ethIn <= valueAfter); // The value in eth of the FUM supply increased by as much as the eth that went in
    }

    /// @dev Test that USM.sol returns eth when defunding.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testDefundEthValue(uint fumOut) public { // To exclude a function from testing, make it internal
        require(fumOut >= 10**14); // 10**14 + 1 fails the last assertion

        uint valueBefore = weth.balanceOf(address(usm));
        uint ethOut = usm.defund(address(this), address(this), fumOut);
        uint valueAfter = weth.balanceOf(address(usm));

        assert(valueBefore - ethOut == valueAfter); // The value in eth of the FUM supply decreased by as much as the value in eth of the FUM that was burnt
    }
}