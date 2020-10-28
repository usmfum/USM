const USM = artifacts.require("USM");
const WETH9 = artifacts.require("USM");
const Proxy = artifacts.require("Proxy");

const wethAddresses = {
    'mainnet' : '0x',
    'ropsten' : '0x',
    'rinkeby' : '0x',
    'kovan'   : '0x'
}

module.exports = async function(deployer, network) {
    let weth

    if (network === 'development') {
        weth = await WETH9.deployed()
    }
    else {
        weth = await WETH9.at(wethAddresses[network])
    }

    const usm = await USM.deployed()
    await deployer.deploy(Proxy, usm.address, weth.address)
}