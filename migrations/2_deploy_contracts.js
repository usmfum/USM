const TestOracle = artifacts.require("TestOracle");
const WETH9 = artifacts.require("WETH9");
const USM = artifacts.require("USM");

module.exports = async function(deployer) {
    // For some reason, this helps `oracle.address`
    // not be undefined??
    await web3.eth.net.getId();
    
    let oracle = await deployer.deploy(TestOracle, "25000", "2");
    let weth = await deployer.deploy(WETH9);
    await deployer.deploy(USM, oracle.address, weth.address);
}