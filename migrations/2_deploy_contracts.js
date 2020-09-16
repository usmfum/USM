const TestOracle = artifacts.require("TestOracle");
const ChainlinkOracle = artifacts.require("ChainlinkOracle");
const USM = artifacts.require("USM");

module.exports = async function(deployer, network) {
    // For some reason, this helps `oracle.address`
    // not be undefined??
    await web3.eth.net.getId();
    
    const oracleAddresses = {
        'ropsten' : '0x30B5068156688f818cEa0874B580206dFe081a03',
        'rinkeby' : '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e',
        'kovan'   : '0x9326BFA02ADD2366b30bacB125260Af641031331'
    }
    const wethAddresses = {
        'ropsten' : 0xc778417e063141139fce010982780140aa0cd5ab,
        'rinkeby' : 0xc778417e063141139fce010982780140aa0cd5ab,
        'kovan'   : 0xd0a1e359811322d97991e03f863a0c30c2cf029c
    }

    let oracle
    if (network !== 'ropsten' && network !== 'rinkeby' && network !== 'kovan') {
        await deployer.deploy(TestOracle, "25000", "2");
        oracle = await TestOracle.deployed()
    }
    else {
        await deployer.deploy(ChainlinkOracle, oracleAddresses[network], "2")
        oracle = await ChainlinkOracle.deployed()
    }

    await deployer.deploy(USM, oracle.address/*, wethAddresses[network]*/);
    const usm = await USM.deployed()
}