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
        'mainnet' : '0x',
        'ropsten' : '0x30B5068156688f818cEa0874B580206dFe081a03',
        'rinkeby' : '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e',
        'kovan'   : '0x9326BFA02ADD2366b30bacB125260Af641031331'
    }
    const compoundAddresses = {
        'mainnet' : '0x',
        'ropsten' : '0x30B5068156688f818cEa0874B580206dFe081a03',
        'rinkeby' : '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e',
        'kovan'   : '0x9326BFA02ADD2366b30bacB125260Af641031331'
    }
    const uniswapAddresses = {
        'mainnet' : '0x',
        'ropsten' : '0x30B5068156688f818cEa0874B580206dFe081a03',
        'rinkeby' : '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e',
        'kovan'   : '0x9326BFA02ADD2366b30bacB125260Af641031331'
    }

    const shift = '18'
    const chainlinkShift = '8'
    const compoundShift = '6'
    const uniswapShift = '18'

    if (network === 'development') {
        const chainlinkPrice = '38598000000'
        const compoundPrice = '414174999'
        const uniswapReserve0 = '646310144553926227215994'
        const uniswapReserve1 = '254384028636585'
        const uniswapReverseOrder = false
        const uniswapScalePriceBy = '1000000000000000000000000000000'

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