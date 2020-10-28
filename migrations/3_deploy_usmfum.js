const USM = artifacts.require("USM");
const WETH9 = artifacts.require("WETH9");
const Proxy = artifacts.require("Proxy");
const MockCompositeOracle = artifacts.require('MockCompositeOracle')
const CompositeOracle = artifacts.require('CompositeOracle')

const wethAddresses = {
    'mainnet' : '0x',
    'ropsten' : '0x',
    'rinkeby' : '0x',
    'kovan'   : '0x'
}

module.exports = async function(deployer, network) {
    let oracle
    let weth

    if (network === 'development') {
        oracle = await MockCompositeOracle.deployed()

        await deployer.deploy(WETH9);
        weth = await WETH9.deployed()
    }
    else {
        oracle = await CompositeOracle.deployed()
        weth = await WETH9.at(wethAddresses[network])
    }

    await deployer.deploy(USM, oracle.address, weth.address);
}