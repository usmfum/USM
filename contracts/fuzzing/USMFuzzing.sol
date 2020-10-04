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
        int valueBefore = usmValue() + fumValue();
        uint usmOut = usm.mint(address(this), address(this), ethIn);
        int valueMiddle = usmValue() + fumValue();

        assert(valueBefore + toInt(ethIn) == valueMiddle); // The value in eth of the USM supply increased by as much as the eth that went in

        uint ethOut = usm.burn(address(this), address(this), usmOut);
        int valueAfter = usmValue() + fumValue();

        assert(ethOut <= ethIn); // Minting and then burning USM should never produce an Eth profit
        assert(valueBefore == valueAfter); // The value in eth of the USM supply decreased by as much as the value in eth of the USM that was burnt
    }

    /// @dev Test minting USM increases the value of the system by the same amount as Eth provided, and that burning does the inverse.
    /// Any function that is public will be run as a test, with random values assigned to each parameter
    function testFundAndDefundEthValue(uint ethIn) public { // To exclude a function from testing, make it internal
        weth.mint(ethIn);
        int valueBefore = fumValue();
        uint fumOut = usm.fund(address(this), address(this), ethIn);
        int valueMiddle = fumValue();

        assert(valueBefore + toInt(ethIn) == valueMiddle); // The value in eth of the FUM supply increased by as much as the eth that went in

        uint ethOut = usm.defund(address(this), address(this), fumOut);
        int valueAfter = fumValue();

        assert(ethOut <= ethIn); // Funding and then defunding FUM should never produce an Eth profit, despite fee distribution
        assert(valueBefore == valueAfter); // The value in eth of the FUM supply decreased by as much as the value in eth of the FUM that was burnt
    }

    function fumValue() internal view returns(int) {
        int b = usm.ethBuffer();
        uint s = fum.totalSupply();
        return (b > 0 && s > 0) ? b / toInt(s) : 0;
    }

    function usmValue() internal view returns(int) {
        return toInt(usm.usmToEth(usm.totalSupply()));
    }

    function toInt(uint x) internal pure returns(int) {
        require(x < (type(uint).max)/2);
        return int(x);
    }
}