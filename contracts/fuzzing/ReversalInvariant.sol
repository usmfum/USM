// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.7;
import "../USM.sol";
import "../oracles/TestOracle.sol";
import "../mocks/MockWETH9.sol";
import "@nomiclabs/buidler/console.sol";

contract ReversalInvariant is USM {

    constructor() public USM(address(new TestOracle(25000000000, 8)), address(new MockWETH9())) { }

    /// @dev Test that burning usm renders less than the eth that was used for minting it. When the transactions happen atomically.
    function testMintAndBurn(
        uint fumSupply,
        uint usmSupply,
        uint ethBalance,
        uint oraclePrice,
        uint ethIn,
        uint32 fundDefundAdjustmentStoredTimestamp,
        uint224 fundDefundAdjustmentStoredValue,
        uint32 mintBurnAdjustmentStoredTimestamp,
        uint224 mintBurnAdjustmentStoredValue
    ) public {
        // Set parameters within range
        oraclePrice %= 1e14;
        fundDefundAdjustmentStoredTimestamp %= uint32(block.timestamp);
        // fundDefundAdjustmentStoredValue <- Reasonable range for this?
        mintBurnAdjustmentStoredTimestamp %= uint32(block.timestamp);
        // mintBurnAdjustmentStoredValue <- Reasonable range for this?
        
        // Set contract state
        fum.mint(address(this), fumSupply);
        _mint(address(this), usmSupply);
        MockWETH9(payable(address(eth))).mint(ethBalance);
        TestOracle(address(oracle)).setPrice(oraclePrice);
        fundDefundAdjustmentStored = TimedValue({
            timestamp: fundDefundAdjustmentStoredTimestamp,
            value: fundDefundAdjustmentStoredValue
        });
        mintBurnAdjustmentStored = TimedValue({
            timestamp: mintBurnAdjustmentStoredTimestamp,
            value: mintBurnAdjustmentStoredValue
        });

        // Transactions
        uint usmOut = this.mint(address(this), address(this), ethIn);
        uint ethOut = this.burn(address(this), address(this), usmOut);

        // This is what we are testing
        assert(ethOut < ethIn);

        // Parameters influencing mint
        // fum.totalSupply()
        // oracle price
        // eth.balanceOf(this)
        // ethIn <- Input
        // block.timestamp
        // fundDefundAdjustmentStored.timestamp
        // fundDefundAdjustmentStored.value
        // mintBurnAdjustmentStored.timestamp
        // mintBurnAdjustmentStored.value
        // -> usmOut

        // Parameters influencing burn
        // oraclePrice
        // eth.balanceOf(this)
        // usmOut <- Input
        // usm.totalSupply()
        // block.timestamp
        // fundDefundAdjustmentStored.timestamp
        // fundDefundAdjustmentStored.value
        // mintBurnAdjustmentStored.timestamp
        // mintBurnAdjustmentStored.value
    }
}