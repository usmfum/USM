const USM = artifacts.require("USM");
const WETH9 = artifacts.require("USM");
const Proxy = artifacts.require("Proxy");

const wethAddresses = {
    'mainnet' : '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    'mainnet-ganache' : '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
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