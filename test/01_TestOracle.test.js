const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')

const UniswapAnchoredView = artifacts.require('MockUniswapAnchoredView')
const CompoundOracle = artifacts.require('CompoundOpenOracle')

const UniswapV2Pair = artifacts.require('MockUniswapV2Pair')
const UniswapTWAPOracle = artifacts.require('OurUniswapV2TWAPOracle')

const MedianOracle = artifacts.require('MedianOracle')

const GasMeasuredOracleWrapper = artifacts.require('GasMeasuredOracleWrapper')

require('chai').use(require('chai-as-promised')).should()

contract('Oracle pricing', (accounts) => {
  const [TEN, WAD] = [10, '1000000000000000000'].map(function (n) { return new BN(n) })

  const testPriceWAD = '250000000000000000000'              // TestOracle just uses WAD (18-dec-place) pricing

  const chainlinkPrice = '38598000000'                      // Chainlink aggregator (AggregatorV3Interface) stores 8 dec places
  const chainlinkPriceWAD = new BN(chainlinkPrice + '0000000000') // We want 18 dec places, so add 10 0s

  const compoundPrice = '414174999'                         // Compound view (UniswapAnchoredView) stores 6 dec places
  const compoundPriceWAD = new BN(compoundPrice + '000000000000') // We want 18 dec places, so add 12 0s

  const uniswapCumPriceScaleFactor = (new BN(2)).pow(new BN(112))

  const ethUsdtTokenToUse = new BN(0)
  const ethUsdtCumPrice0_0 = new BN('30197009659458262808281833965635') // From the ETH/USDT pair.  See OurUniswapV2TWAPOracle
  const ethUsdtTimestamp_0 = new BN('1606780564')
  const ethUsdtCumPrice0_1 = new BN('30198349396553956234684790868151')
  const ethUsdtTimestamp_1 = new BN('1606781184')
  const ethUsdtEthDecimals = new BN(-12)
  const ethUsdtScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(ethUsdtEthDecimals.neg()))

  const usdcEthTokenToUse = new BN(1)
  const usdcEthCumPrice1_0 = new BN('31375939132666967530700283664103') // From the USDC/ETH pair
  const usdcEthTimestamp_0 = new BN('1606780664')
  const usdcEthCumPrice1_1 = new BN('31378725947216452626380862836246')
  const usdcEthTimestamp_1 = new BN('1606782003')
  const usdcEthEthDecimals = new BN(-12)
  const usdcEthScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(usdcEthEthDecimals.neg()))

  const daiEthTokenToUse = new BN(1)
  const daiEthCumPrice1_0 = new BN('30339833685805974401597062880404438583745289') // From the DAI/ETH pair
  const daiEthTimestamp_0 = new BN('1606780728')
  const daiEthCumPrice1_1 = new BN('30340852730044753766501469633003499944051151')
  const daiEthTimestamp_1 = new BN('1606781448')
  const daiEthEthDecimals = new BN(0)
  const daiEthScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(daiEthEthDecimals.neg()))

  function median(a, b, c) {
    const ab = a > b
    const bc = b > c
    const ca = c > a
    return (ca == ab ? a : (ab == bc ? b : c))
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = x.sub(y).abs()
    diff.should.be.bignumber.lte(x.add(y).abs().div(new BN(1000000)))
  }

  describe("with TestOracle", () => {
    const [deployer] = accounts
    let oracle

    beforeEach(async () => {
      oracle = await TestOracle.new(testPriceWAD, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "test", { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      oraclePrice.toString().should.equal(testPriceWAD)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })

  describe("with ChainlinkOracle", () => {
    const [deployer] = accounts
    let oracle
    let aggregator

    beforeEach(async () => {
      aggregator = await Aggregator.new({ from: deployer })
      await aggregator.set(chainlinkPrice)

      oracle = await ChainlinkOracle.new(aggregator.address, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "chainlink", { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      oraclePrice.toString().should.equal(chainlinkPriceWAD.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })

  describe("with CompoundOracle", () => {
    const [deployer] = accounts
    let oracle
    let anchoredView

    beforeEach(async () => {
      anchoredView = await UniswapAnchoredView.new({ from: deployer })
      await anchoredView.set(compoundPrice)

      oracle = await CompoundOracle.new(anchoredView.address, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "compound", { from: deployer })
      await oracle.refreshPrice()
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      oraclePrice.toString().should.equal(compoundPriceWAD.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })

  describe("with OurUniswapV2TWAPOracle", () => {
    const [deployer] = accounts
    let oracle
    let pair

    beforeEach(async () => {
      pair = await UniswapV2Pair.new({ from: deployer })
      await pair.setReserves(0, 0, ethUsdtTimestamp_0)
      await pair.setCumulativePrices(ethUsdtCumPrice0_0, 0)

      oracle = await UniswapTWAPOracle.new(pair.address, ethUsdtTokenToUse, ethUsdtEthDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "uniswapTWAP", { from: deployer })
      await oracle.refreshPrice()

      await pair.setReserves(0, 0, ethUsdtTimestamp_1)
      await pair.setCumulativePrices(ethUsdtCumPrice0_1, 0)
      //await oracle.refreshPrice() // Not actually needed, unless we do further testing moving timestamps further forward
    })

    it('returns the correct price', async () => {
      const oraclePrice1 = (await oracle.latestPrice())[0]

      const targetOraclePriceNum = (ethUsdtCumPrice0_1.sub(ethUsdtCumPrice0_0)).mul(WAD)
      const targetOraclePriceDenom = (ethUsdtTimestamp_1.sub(ethUsdtTimestamp_0)).mul(ethUsdtScaleFactor)
      const targetOraclePrice1 = targetOraclePriceNum.div(targetOraclePriceDenom)
      shouldEqualApprox(oraclePrice1, targetOraclePrice1)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })

  describe("with MedianOracle", () => {
    const [deployer] = accounts
    let rawOracle, oracle
    let chainlinkAggregator, compoundView, usdcEthPair

    beforeEach(async () => {
      chainlinkAggregator = await Aggregator.new({ from: deployer })
      await chainlinkAggregator.set(chainlinkPrice)

      compoundView = await UniswapAnchoredView.new({ from: deployer })
      await compoundView.set(compoundPrice)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(0, 0, usdcEthTimestamp_0)
      await usdcEthPair.setCumulativePrices(0, usdcEthCumPrice1_0)

      rawOracle = await MedianOracle.new(chainlinkAggregator.address, compoundView.address,
        usdcEthPair.address, usdcEthTokenToUse, usdcEthEthDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(rawOracle.address, "median", { from: deployer })
      await oracle.refreshPrice()

      await usdcEthPair.setReserves(0, 0, usdcEthTimestamp_1)
      await usdcEthPair.setCumulativePrices(0, usdcEthCumPrice1_1)
      //await oracle.refreshPrice() // Not actually needed, unless we do further testing moving timestamps further forward
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      const uniswapPrice = (await rawOracle.latestUniswapTWAPPrice())[0]
      const targetOraclePrice = median(chainlinkPriceWAD, compoundPriceWAD, uniswapPrice)
      oraclePrice.toString().should.equal(targetOraclePrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })
})
