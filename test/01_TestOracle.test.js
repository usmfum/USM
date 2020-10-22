const TestOracle = artifacts.require('TestOracle')
const Medianizer = artifacts.require('MockMakerMedianizer')
const MakerOracle = artifacts.require('MakerOracle')
const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')

require('chai').use(require('chai-as-promised')).should()

contract('TestOracle', (accounts) => {
  const [deployer] = accounts
  let oracle

  const price = '25000'
  const shift = '8'

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
  })

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(price)
    })

    it('returns the correct decimal shift', async () => {
      let oracleShift = (await oracle.decimalShift())
      oracleShift.toString().should.equal(shift)
    })
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

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(price)
    })

    it('returns the correct decimal shift', async () => {
      let oracleShift = (await oracle.decimalShift())
      oracleShift.toString().should.equal(shift)
    })
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

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(price)
    })

    it('returns the correct decimal shift', async () => {
      let oracleShift = (await oracle.decimalShift())
      oracleShift.toString().should.equal(shift)
    })
  })
})