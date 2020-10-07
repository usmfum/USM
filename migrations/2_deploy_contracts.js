const TestOracle = artifacts.require("TestOracle");
const ChainlinkOracle = artifacts.require("ChainlinkOracle");
const USM = artifacts.require("USM");
const FUM = artifacts.require("USM");
const WETH9 = artifacts.require("USM");
const Proxy = artifacts.require("Proxy");

module.exports = async function(deployer, network) {
    // For some reason, this helps `oracle.address`
    // not be undefined??
    await web3.eth.net.getId();
    const deployer = await web3.eth.getAccounts()[0]
    
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
    let weth
    if (network !== 'ropsten' && network !== 'rinkeby' && network !== 'kovan') {
        await deployer.deploy(TestOracle, "25000000000", "8");
        oracle = await TestOracle.deployed()

        await deployer.deploy(WETH9);
        weth = await WETH9.deployed()
    }
    else {
        await deployer.deploy(ChainlinkOracle, oracleAddresses[network], "8")
        oracle = await ChainlinkOracle.deployed()
        weth = await WETH9.at(wethAddresses[network])
    }

    await deployer.deploy(USM, oracle.address, weth.address);
    const usm = await USM.deployed()
    const fum = await FUM.at(await usm.fum())

    await deployer.deploy(Proxy, usm.address, weth.address)
    const proxy = await Proxy.deployed()

    await weth.deposit(deployer, 1)
    await weth.approve(usm.address, 1)
    await usm.fund(deployer, deployer, 1)
    await fum.transfer('0x0000000000000000000000000000000000000001', 1)
}