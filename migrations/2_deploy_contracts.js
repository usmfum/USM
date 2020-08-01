const USDOracle = artifacts.require("USDOracle");
const USM = artifacts.require("USM");

module.exports = async function(deployer) {
    // For some reason, this helps `oracle.address`
    // not be undefined??
    await web3.eth.net.getId();
    
    let oracle = await deployer.deploy(USDOracle);
    await deployer.deploy(USM, oracle.address);
}