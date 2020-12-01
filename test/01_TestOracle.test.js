const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')

const Medianizer = artifacts.require('MockMakerMedianizer')
const GasMakerOracle = artifacts.require('GasMeasuredMakerOracle')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const GasChainlinkOracle = artifacts.require('GasMeasuredChainlinkOracle')

const UniswapAnchoredView = artifacts.require('MockUniswapAnchoredView')
const GasCompoundOracle = artifacts.require('GasMeasuredCompoundOpenOracle')

const UniswapV2Pair = artifacts.require('MockUniswapV2Pair')
const GasUniswapSpotOracle = artifacts.require('GasMeasuredOurUniswapV2SpotOracle')

const GasUniswapMedianSpotOracle = artifacts.require('GasMeasuredUniswapMedianSpotOracle')

const GasMedianOracle = artifacts.require('GasMeasuredMedianOracle')

require('chai').use(require('chai-as-promised')).should()

contract('Oracle pricing', (accounts) => {
  const testPriceWAD = '250000000000000000000'              // TestOracle just uses WAD (18-dec-place) pricing

  const makerPriceWAD = '392110000000000000000'             // Maker medianizer (IMakerPriceFeed) returns WAD 18-dec-place prices

  const chainlinkPrice = '38598000000'                      // Chainlink aggregator (AggregatorV3Interface) stores 8 dec places
  const chainlinkPriceWAD = chainlinkPrice + '0000000000'   // We want 18 dec places, so add 10 0s

  const compoundPrice = '414174999'                         // Compound view (UniswapAnchoredView) stores 6 dec places
  const compoundPriceWAD = compoundPrice + '000000000000'   // We want 18 dec places, so add 12 0s

  const ethDecimals = new BN(18)                            // See OurUniswapV2SpotOracle
  const usdtDecimals = new BN(6)
  const usdcDecimals = new BN(6)
  const daiDecimals = new BN(18)

  const ethUsdtReserve0 = '646310144553926227215994'        // From the ETH/USDT pair.  See OurUniswapV2SpotOracle
  const ethUsdtReserve1 = '254384028636585'
  const ethUsdtTokensInReverseOrder = false
  const ethUsdtScaleFactor = (new BN(10)).pow(new BN(30))   // This pair gives -12 dec places, we need 18.  See OurUniswapV2SpotOracle

  const usdcEthReserve0 = '260787673159143'
  const usdcEthReserve1 = '696170744128378724814084'
  const usdcEthTokensInReverseOrder = true
  const usdcEthScaleFactor = (new BN(10)).pow(new BN(30))   // This pair gives -12 dec places, we need 18

  const daiEthReserve0 = '178617913077721329213551886'
  const daiEthReserve1 = '480578265664207487333589'
  const daiEthTokensInReverseOrder = true
  const daiEthScaleFactor = (new BN(10)).pow(new BN(18))    // This pair gives 0 dec places, we need 18

  describe("with TestOracle", () => {
    const [deployer] = accounts
    let oracle

    beforeEach(async () => {
      oracle = await TestOracle.new(testPriceWAD, { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(testPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with MakerOracle", () => {
    const [deployer] = accounts
    let oracle
    let medianizer

    beforeEach(async () => {
      medianizer = await Medianizer.new({ from: deployer })
      await medianizer.set(makerPriceWAD)

      oracle = await GasMakerOracle.new(medianizer.address, { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(makerPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with ChainlinkOracle", () => {
    const [deployer] = accounts
    let oracle
    let aggregator

    beforeEach(async () => {
      aggregator = await Aggregator.new({ from: deployer })
      await aggregator.set(chainlinkPrice)

      oracle = await GasChainlinkOracle.new(aggregator.address, { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(chainlinkPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with CompoundOracle", () => {
    const [deployer] = accounts
    let oracle
    let anchoredView

    beforeEach(async () => {
      anchoredView = await UniswapAnchoredView.new({ from: deployer })
      await anchoredView.set(compoundPrice)

      oracle = await GasCompoundOracle.new(anchoredView.address, { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(compoundPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with OurUniswapV2SpotOracle", () => {
    const [deployer] = accounts
    let oracle
    let pair

    beforeEach(async () => {
      pair = await UniswapV2Pair.new({ from: deployer })
      await pair.set(ethUsdtReserve0, ethUsdtReserve1)

      oracle = await GasUniswapSpotOracle.new(pair.address, ethDecimals, usdtDecimals, ethUsdtTokensInReverseOrder,
                                              { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      const targetPrice = (new BN(ethUsdtReserve1)).mul(ethUsdtScaleFactor).div(new BN(ethUsdtReserve0)) // reverseOrder = false
      oraclePrice.toString().should.equal(targetPrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with UniswapMedianSpotOracle", () => {
    const [deployer] = accounts
    let oracle
    let ethUsdtPair, usdcEthPair, daiEthPair

    beforeEach(async () => {
      ethUsdtPair = await UniswapV2Pair.new({ from: deployer })
      await ethUsdtPair.set(ethUsdtReserve0, ethUsdtReserve1)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.set(usdcEthReserve0, usdcEthReserve1)

      daiEthPair = await UniswapV2Pair.new({ from: deployer })
      await daiEthPair.set(daiEthReserve0, daiEthReserve1)

      oracle = await GasUniswapMedianSpotOracle.new(
          [ethUsdtPair.address, usdcEthPair.address, daiEthPair.address],
          [ethDecimals, usdcDecimals, daiDecimals],
          [usdtDecimals, ethDecimals, ethDecimals],
          [ethUsdtTokensInReverseOrder, usdcEthTokensInReverseOrder, daiEthTokensInReverseOrder], { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      // Of the three pairs, the USDC/ETH pair has the middle price, so UniswapMedianOracle's price should match it:
      const targetPrice = (new BN(usdcEthReserve0)).mul(usdcEthScaleFactor).div(new BN(usdcEthReserve1)) // reverseOrder = true
      oraclePrice.toString().should.equal(targetPrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with MedianOracle", () => {
    const [deployer] = accounts
    let oracle
    let makerMedianizer, chainlinkAggregator, compoundView, ethUsdtPair, usdcEthPair, daiEthPair

    beforeEach(async () => {
      //makerMedianizer = await Medianizer.new({ from: deployer })
      //await makerMedianizer.set(makerPriceWAD)

      chainlinkAggregator = await Aggregator.new({ from: deployer })
      await chainlinkAggregator.set(chainlinkPrice)

      compoundView = await UniswapAnchoredView.new({ from: deployer })
      await compoundView.set(compoundPrice)

      ethUsdtPair = await UniswapV2Pair.new({ from: deployer })
      await ethUsdtPair.set(ethUsdtReserve0, ethUsdtReserve1)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.set(usdcEthReserve0, usdcEthReserve1)

      daiEthPair = await UniswapV2Pair.new({ from: deployer })
      await daiEthPair.set(daiEthReserve0, daiEthReserve1)

      oracle = await GasMedianOracle.new(chainlinkAggregator.address, compoundView.address,
        [ethUsdtPair.address, usdcEthPair.address, daiEthPair.address],
        [ethDecimals, usdcDecimals, daiDecimals],
        [usdtDecimals, ethDecimals, ethDecimals],
        [ethUsdtTokensInReverseOrder, usdcEthTokensInReverseOrder, daiEthTokensInReverseOrder], { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      // Of the three oracles (Chainlink, Compound, UniswapMedian), Chainlink's is in the middle, so MedianOracle should match it:
      oraclePrice.toString().should.equal(chainlinkPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })
})
