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
        weth.mint(ethIn);
        uint valueBefore = usm.usmToEth(usm.totalSupply());
        uint usmOut = usm.mint(address(this), address(this), ethIn);
        uint valueMiddle = usm.usmToEth(usm.totalSupply());

        // assert(valueBefore + ethIn == valueMiddle); // The value in eth of the USM supply increased by as much as the eth that went in

        uint ethOut = usm.burn(address(this), address(this), usmOut);
        uint valueAfter = usm.usmToEth(usm.totalSupply());

        assert(ethOut == ethIn); // Minting and then burning USM is neutral in eth terms in absence of oracle changes
        // assert(valueBefore == valueAfter); // The value in eth of the USM supply decreased by as much as the value in eth of the USM that was burnt
    }

    /// @dev Test minting USM increases the value of the system by the same amount as Eth provided, and that burning does the inverse.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testFundAndDefundEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        weth.mint(ethIn);
        uint valueBefore =  usm.fumPrice(IUSM.Side.Buy).wadMul(fum.totalSupply());
        uint fumOut = usm.fund(address(this), address(this), ethIn);
        uint valueMiddle = usm.fumPrice(IUSM.Side.Buy).wadMul(fum.totalSupply());

        // assert(valueBefore + ethIn == valueMiddle); // The value in eth of the FUM supply increased by as much as the eth that went in

        uint ethOut = usm.defund(address(this), address(this), fumOut);
        uint valueAfter = usm.fumPrice(IUSM.Side.Buy).wadMul(fum.totalSupply());

        assert(ethOut <= ethIn); // Minting and then burning FUM is neutral or losses value in eth terms in absence of oracle changes
        // assert(valueBefore == valueAfter); // The value in eth of the FUM supply decreased by as much as the value in eth of the FUM that was burnt
    }
}