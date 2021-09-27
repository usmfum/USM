const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')

const CompoundUniswapAnchoredView = artifacts.require('MockCompoundUniswapAnchoredView')
const CompoundOracle = artifacts.require('CompoundOpenOracle')

const UniswapV2Pair = artifacts.require('MockUniswapV2Pair')
const UniswapV2TWAPOracle = artifacts.require('UniswapV2TWAPOracle')

const UniswapV3Pool = artifacts.require('MockUniswapV3Pool')
const UniswapV3TWAPOracle = artifacts.require('UniswapV3TWAPOracle')

const MedianOracle = artifacts.require('MedianOracle')

const GasMeasuredOracleWrapper = artifacts.require('GasMeasuredOracleWrapper')

require('chai').use(require('chai-as-promised')).should()

contract('Oracle pricing', (accounts) => {
  const [ZERO, ONE, TEN, WAD] = [0, 1, 10, '1000000000000000000'].map(function (n) { return new BN(n) })

  const testPriceWAD = '250000000000000000000'              // TestOracle just uses WAD (18-dec-place) pricing

  const chainlinkPrice = '38598000000'                      // Chainlink aggregator (AggregatorV3Interface) stores 8 dec places
  const chainlinkPriceWAD = new BN(chainlinkPrice + '0000000000') // We want 18 dec places, so add 10 0s
  const chainlinkTime = '1613550219'                        // Timestamp ("updatedAt") of the Chainlink price

  const compoundPrice = '414174999'                         // CompoundUniswapAnchoredView stores 6 dec places
  const compoundPriceWAD = new BN(compoundPrice + '000000000000') // We want 18 dec places, so add 12 0s

  const uniswapCumPriceScaleFactor = (new BN(2)).pow(new BN(112))

  const ethUsdtTokenToPrice = new BN(0)
  const ethUsdtDecimals = new BN(-12)
  const ethUsdtV2CumPrice0_0 = new BN('30197009659458262808281833965635') // From the V2 ETH/USDT pair, see UniswapV2TWAPOracle
  const ethUsdtV2Timestamp_0 = new BN('1606780564')
  const ethUsdtV2CumPrice0_1 = new BN('30198349396553956234684790868151')
  const ethUsdtV2Timestamp_1 = new BN('1606781184')
  const ethUsdtV2ScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(ethUsdtDecimals.neg()))
  const ethUsdtV3Timestamp0 = new BN('1632453299')
  const ethUsdtV3TickCum0 = new BN('-2406882279470') // From the V3 ETH/USDT pool
  const ethUsdtV3Timestamp1 = new BN('1632453899')
  const ethUsdtV3TickCum1 = new BN('-2406999836487')

  const usdcEthTokenToPrice = new BN(1)
  const usdcEthDecimals = new BN(-12)
  const usdcEthV2CumPrice1_0 = new BN('31375939132666967530700283664103') // From the V2 USDC/ETH pair
  const usdcEthV2Timestamp_0 = new BN('1606780664')
  const usdcEthV2CumPrice1_1 = new BN('31378725947216452626380862836246')
  const usdcEthV2Timestamp_1 = new BN('1606782003')
  const usdcEthV2ScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(usdcEthDecimals.neg()))
  const usdcEthV3Timestamp0 = new BN('1632203136')
  const usdcEthV3TickCum0 = new BN('2357826690419') // From the V3 USDC/ETH pool
  const usdcEthV3Timestamp1 = new BN('1632203736')
  const usdcEthV3TickCum1 = new BN('2357944474677')

  const daiEthTokenToPrice = new BN(1)
  const daiEthDecimals = new BN(0)
  const daiEthV2CumPrice1_0 = new BN('30339833685805974401597062880404438583745289') // From the V2 DAI/ETH pair
  const daiEthV2Timestamp_0 = new BN('1606780728')
  const daiEthV2CumPrice1_1 = new BN('30340852730044753766501469633003499944051151')
  const daiEthV2Timestamp_1 = new BN('1606781448')
  const daiEthV2ScaleFactor = uniswapCumPriceScaleFactor.div(TEN.pow(daiEthDecimals.neg()))

  function median(a, b, c) {
    const ab = a.gt(b)      // Not "a > b", which seems to do a lexicographic comparison.  JavaScript numbers man, FML...
    const bc = b.gt(c)
    const ca = c.gt(a)
    return (ca == ab ? a : (ab == bc ? b : c))
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = x.sub(y).abs()
    diff.should.be.bignumber.lte(x.add(y).abs().div(new BN(1000000)))
  }

  function fl(w) { // Converts a WAD fixed-point (eg, 2.7e18) to an unscaled float (2.7).  Of course may lose a bit of precision
    return parseFloat(w) / WAD
  }

  function wad(x) {
    return new BN(BigInt(Math.round(parseFloat(x) * WAD)))
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
      await aggregator.set(chainlinkPrice, chainlinkTime)

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
      anchoredView = await CompoundUniswapAnchoredView.new({ from: deployer })
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

  describe("with UniswapV2TWAPOracle", () => {
    const [deployer] = accounts
    let oracle
    let pair

    beforeEach(async () => {
      pair = await UniswapV2Pair.new({ from: deployer })
      await pair.setReserves(0, 0, ethUsdtV2Timestamp_0)
      await pair.setCumulativePrices(ethUsdtV2CumPrice0_0, 0)

      oracle = await UniswapV2TWAPOracle.new(pair.address, ethUsdtTokenToPrice, ethUsdtDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "uniswapV2TWAP", { from: deployer })
      await oracle.refreshPrice()

      await pair.setReserves(0, 0, ethUsdtV2Timestamp_1)
      await pair.setCumulativePrices(ethUsdtV2CumPrice0_1, 0)
      await oracle.refreshPrice()
    })

    it('returns the correct price', async () => {
      const oraclePrice1 = (await oracle.latestPrice())[0]

      const targetOraclePriceNum = (ethUsdtV2CumPrice0_1.sub(ethUsdtV2CumPrice0_0)).mul(WAD)
      const targetOraclePriceDenom = (ethUsdtV2Timestamp_1.sub(ethUsdtV2Timestamp_0)).mul(ethUsdtV2ScaleFactor)
      const targetOraclePrice1 = targetOraclePriceNum.div(targetOraclePriceDenom)
      shouldEqualApprox(oraclePrice1, targetOraclePrice1)
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })

  describe("with UniswapV3TWAPOracle", () => {
    const [deployer] = accounts
    let oracle
    let pool

    beforeEach(async () => {
      pool = await UniswapV3Pool.new({ from: deployer })
      await pool.setObservation(ZERO, ethUsdtV3Timestamp0, ethUsdtV3TickCum0)
      await pool.setObservation(ONE, ethUsdtV3Timestamp1, ethUsdtV3TickCum1)

      oracle = await UniswapV3TWAPOracle.new(pool.address, ethUsdtTokenToPrice, ethUsdtDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(oracle.address, "uniswapV3TWAP", { from: deployer })
      await oracle.refreshPrice()
    })

    it('returns the correct price', async () => {
      const oraclePrice1 = (await oracle.latestPrice())[0]

      const targetOraclePriceNum = ethUsdtV3TickCum1.sub(ethUsdtV3TickCum0)
      const targetOraclePriceDenom = ethUsdtV3Timestamp1.sub(ethUsdtV3Timestamp0)
      // Use Math.floor() here, not just .div(), since for negative ticks (like ETH/USDT's) we must round down, not towards 0!
      let targetOraclePriceExp = Math.floor(parseFloat(targetOraclePriceNum) / parseFloat(targetOraclePriceDenom))
      if (ethUsdtTokenToPrice.eq(ONE)) {
        targetOraclePriceExp *= -1 // If we're pricing token1 (ie, the 2nd one), negate the exponent
      }
      targetOraclePrice1 = wad((1.0001 ** targetOraclePriceExp) / (10 ** ethUsdtDecimals))
      //console.log("matches? " + fl(oraclePrice1) + ", " + targetOraclePriceNum + ", " + targetOraclePriceDenom + ", " + targetOraclePriceExp + ", " + (new BN(1)).eq(ONE) + ", " + (new BN(0)).eq(ONE) + ", " + fl(targetOraclePrice1))
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
      await chainlinkAggregator.set(chainlinkPrice, chainlinkTime)

      compoundView = await CompoundUniswapAnchoredView.new({ from: deployer })
      await compoundView.set(compoundPrice)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(0, 0, usdcEthV2Timestamp_0)
      await usdcEthPair.setCumulativePrices(0, usdcEthV2CumPrice1_0)

      rawOracle = await MedianOracle.new(chainlinkAggregator.address, compoundView.address,
        usdcEthPair.address, usdcEthTokenToPrice, usdcEthDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(rawOracle.address, "median", { from: deployer })
      await oracle.refreshPrice()

      await usdcEthPair.setReserves(0, 0, usdcEthV2Timestamp_1)
      await usdcEthPair.setCumulativePrices(0, usdcEthV2CumPrice1_1)
      await oracle.refreshPrice()
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      const uniswapPrice = (await rawOracle.latestUniswapV2TWAPPrice())[0]
      const targetOraclePrice = median(chainlinkPriceWAD, compoundPriceWAD, uniswapPrice)
      oraclePrice.toString().should.equal(targetOraclePrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })
})
