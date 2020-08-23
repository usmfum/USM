const ChainlinkOracle = artifacts.require("ChainlinkOracle");
const USM = artifacts.require("USM");

module.exports = async function(deployer) {
    // For some reason, this helps `oracle.address`
    // not be undefined??
    await web3.eth.net.getId();
    
    let oracle = await deployer.deploy(ChainlinkOracle, "0x30B5068156688f818cEa0874B580206dFe081a03", 8);
    await deployer.deploy(USM, oracle.address);
}