const MockAggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')
const MockUniswapAnchoredView = artifacts.require('MockUniswapAnchoredView')
const CompoundOracle = artifacts.require('CompoundOpenOracle')
const MockUniswapV2Pair = artifacts.require('MockUniswapV2Pair')
const UniswapOracle = artifacts.require('OurUniswapV2SpotOracle')
const MockCompositeOracle = artifacts.require('MockCompositeOracle')
const CompositeOracle = artifacts.require('CompositeOracle')

module.exports = async function(deployer, network) {
    
    const chainlinkAddresses = {
        'mainnet' : '0xaEA2808407B7319A31A383B6F8B60f04BCa23cE2',
        'mainnet-ganache' : '0xaEA2808407B7319A31A383B6F8B60f04BCa23cE2'
    }
    const compoundAddresses = {
        'mainnet' : '0x922018674c12a7f0d394ebeef9b58f186cde13c1',
        'mainnet-ganache' : '0x922018674c12a7f0d394ebeef9b58f186cde13c1'
    }
    const uniswapAddresses = {
        'mainnet' : '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852',
        'mainnet-ganache' : '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852'
    }

    const shift = '18'
    const chainlinkShift = '8'
    const compoundShift = '6'
    const uniswapShift = '18'
    const uniswapReverseOrder = false // TODO: Find out
    const uniswapScalePriceBy = '1000000000000000000000000000000'

    if (network === 'development') {
        const chainlinkPrice = '38598000000'
        const compoundPrice = '414174999'
        const uniswapReserve0 = '646310144553926227215994'
        const uniswapReserve1 = '254384028636585'

        await deployer.deploy(MockAggregator)
        aggregator = await MockAggregator.deployed()
        await aggregator.set(chainlinkPrice)
        await deployer.deploy(ChainlinkOracle, aggregator.address, chainlinkShift)
        chainlink = await ChainlinkOracle.deployed()
    
        await deployer.deploy(MockUniswapAnchoredView)
        anchoredView = await MockUniswapAnchoredView.deployed()
        await anchoredView.set(compoundPrice)
        await deployer.deploy(CompoundOracle, anchoredView.address, compoundShift)
        compound = await CompoundOracle.deployed()
    
        await deployer.deploy(MockUniswapV2Pair)
        pair = await MockUniswapV2Pair.deployed()
        await pair.set(uniswapReserve0, uniswapReserve1);
        await deployer.deploy(UniswapOracle, pair.address, uniswapReverseOrder, uniswapShift, uniswapScalePriceBy)
        uniswap = await UniswapOracle.deployed()
  
        await deployer.deploy(MockCompositeOracle, [chainlink.address, compound.address, uniswap.address], shift)
        oracle = await MockCompositeOracle.deployed()
    }
    else {
        await deployer.deploy(ChainlinkOracle, chainlinkAddresses[network], chainlinkShift)
        chainlink = await ChainlinkOracle.deployed()
    
        await deployer.deploy(CompoundOracle, compoundAddresses[network], compoundShift)
        compound = await CompoundOracle.deployed()
    
        await deployer.deploy(UniswapOracle, uniswapAddresses[network], uniswapReverseOrder, uniswapShift, uniswapScalePriceBy)
        uniswap = await UniswapOracle.deployed()
  
        await deployer.deploy(CompositeOracle, [chainlink.address, compound.address, uniswap.address], shift)
        oracle = await CompositeOracle.deployed()
    }
}