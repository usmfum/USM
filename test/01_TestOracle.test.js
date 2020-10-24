const TestOracle = artifacts.require('TestOracle')

const Medianizer = artifacts.require('MockMakerMedianizer')
const MakerOracle = artifacts.require('MakerOracle')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')

const UniswapAnchoredView = artifacts.require('MockUniswapAnchoredView')
const CompoundOracle = artifacts.require('CompoundOpenOracle')

const CompositeOracle = artifacts.require('MockCompositeOracle')


require('chai').use(require('chai-as-promised')).should()

contract('TestOracle', (accounts) => {
  const [deployer] = accounts
  let oracle

  const price = '25000'
  const shift = '8'

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
  })

  it('returns the correct price', async () => {
    let oraclePrice = (await oracle.latestPrice())
    oraclePrice.toString().should.equal(price)
  })

  it('returns the correct decimal shift', async () => {
    let oracleShift = (await oracle.decimalShift())
    oracleShift.toString().should.equal(shift)
  })

  it('returns the price in a transaction', async () => {
    let oraclePrice = (await oracle.latestPriceWithGas())
  })
})

contract('Maker', (accounts) => {
  const [deployer] = accounts
  let oracle
  let medianizer

  const price = '392110000000000000000'
  const shift = '18'

  beforeEach(async () => {
    medianizer = await Medianizer.new({ from: deployer })
    await medianizer.set(price);

    oracle = await MakerOracle.new(medianizer.address, shift, { from: deployer })
  })

  it('returns the correct price', async () => {
    let oraclePrice = (await oracle.latestPrice())
    oraclePrice.toString().should.equal(price)
  })

  it('returns the correct decimal shift', async () => {
    let oracleShift = (await oracle.decimalShift())
    oracleShift.toString().should.equal(shift)
  })

  it('returns the price in a transaction', async () => {
    let oraclePrice = (await oracle.latestPriceWithGas())
  })
})

contract('Chainlink', (accounts) => {
  const [deployer] = accounts
  let oracle
  let aggregator

  const price = '38598000000'
  const shift = '8'

  beforeEach(async () => {
    aggregator = await Aggregator.new({ from: deployer })
    await aggregator.set(price);

    oracle = await ChainlinkOracle.new(aggregator.address, shift, { from: deployer })
  })

  it('returns the correct price', async () => {
    let oraclePrice = (await oracle.latestPrice())
    oraclePrice.toString().should.equal(price)
  })

  it('returns the correct decimal shift', async () => {
    let oracleShift = (await oracle.decimalShift())
    oracleShift.toString().should.equal(shift)
  })

  it('returns the price in a transaction', async () => {
    let oraclePrice = (await oracle.latestPriceWithGas())
  })
})

contract('Compound', (accounts) => {
  const [deployer] = accounts
  let oracle
  let anchoredView

  const price = '414174999'
  const shift = '6'

  beforeEach(async () => {
    anchoredView = await UniswapAnchoredView.new({ from: deployer })
    await anchoredView.set(price);

    oracle = await CompoundOracle.new(anchoredView.address, shift, { from: deployer })
  })

  it('returns the correct price', async () => {
    let oraclePrice = (await oracle.latestPrice())
    oraclePrice.toString().should.equal(price)
  })

  it('returns the correct decimal shift', async () => {
    let oracleShift = (await oracle.decimalShift())
    oracleShift.toString().should.equal(shift)
  })

  it('returns the price in a transaction', async () => {
    let oraclePrice = (await oracle.latestPriceWithGas())
  })
})

contract('CompositeOracle', (accounts) => {
  const [deployer] = accounts
  let oracle
  shift = '18'

  let maker
  let medianizer
  const makerPrice = '392110000000000000000'
  const makerShift = '18'

  let chainlink
  let aggregator
  const chainlinkPrice = '38598000000'
  const chainlinkShift = '8'

  let compound
  let anchoredView
  const compoundPrice = '414174999'
  const compoundShift = '6'

  beforeEach(async () => {
    medianizer = await Medianizer.new({ from: deployer })
    await medianizer.set(makerPrice);
    maker = await MakerOracle.new(medianizer.address, makerShift, { from: deployer })

    aggregator = await Aggregator.new({ from: deployer })
    await aggregator.set(chainlinkPrice);
    chainlink = await ChainlinkOracle.new(aggregator.address, chainlinkShift, { from: deployer })

    anchoredView = await UniswapAnchoredView.new({ from: deployer })
    await anchoredView.set(compoundPrice);
    compound = await CompoundOracle.new(anchoredView.address, compoundShift, { from: deployer })

    oracle = await CompositeOracle.new([maker.address, chainlink.address, compound.address], shift, { from: deployer })
  })

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(makerPrice)
    })

    it('returns the correct decimal shift', async () => {
      let oracleShift = (await oracle.decimalShift())
      oracleShift.toString().should.equal(shift)
    })

    it('returns the price in a transaction', async () => {
      let oraclePrice = (await oracle.latestPriceWithGas())
    })
  })
})