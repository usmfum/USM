// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../IUSM.sol";
import "../USM.sol";
import "../FUM.sol";
import "../mocks/TestOracle.sol";
import "../mocks/MockWETH9.sol";
import "../WadMath.sol";
import "@nomiclabs/buidler/console.sol";

contract USMFuzzingRoundtrip {
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
        weth.mint(ethIn);

        uint usmOut = usm.mint(address(this), address(this), ethIn);
        uint ethOut = usm.burn(address(this), address(this), usmOut);

        assert(ethIn >= ethOut);
    }

    /// @dev Test minting USM increases the value of the system by the same amount as Eth provided, and that burning does the inverse.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testFundAndDefundEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        weth.mint(ethIn);

        uint fumOut = usm.fund(address(this), address(this), ethIn);
        uint ethOut = usm.defund(address(this), address(this), fumOut);

        require(fum.totalSupply() > 0); // Edge case - Removing all FUM leaves ETH in USM that will be claimed by the next `fund()`

        assert(ethIn >= ethOut);
    }

    // Test that ethBuffer grows up with the fund/defund/mint/burn fee, plus minus eth for fund eth from defund
    // Test that with two consecutive ops, the second one gets a worse price
}