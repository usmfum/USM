const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const ChainlinkOracle = artifacts.require('ChainlinkOracle')

const UniswapV3Pool = artifacts.require('MockUniswapV3Pool')
const UniswapV3TWAPOracle = artifacts.require('UniswapV3TWAPOracle')

const MedianOracle = artifacts.require('MedianOracle')

const GasMeasuredOracleWrapper = artifacts.require('GasMeasuredOracleWrapper')

require('chai').use(require('chai-as-promised')).should()

contract('Oracle pricing', (accounts) => {
  const [ZERO, ONE, TEN, WAD] = [0, 1, 10, '1000000000000000000'].map(function (n) { return new BN(n) })

  const testPriceWAD = '250000000000000000000'              // TestOracle just uses WAD (18-dec-place) pricing

  const chainlinkPrice = '309647000000'                     // Chainlink aggregator (AggregatorV3Interface) stores 8 dec places
  const chainlinkPriceWAD = new BN(chainlinkPrice + '0000000000') // We want 18 dec places, so add 10 0s
  const chainlinkTime = '1613550219'                        // Timestamp ("updatedAt") of the Chainlink price

  const uniswapCumPriceScaleFactor = (new BN(2)).pow(new BN(112))

  const ethUsdtTokenToPrice = new BN(0)
  const ethUsdtDecimals = new BN(-12)
  const ethUsdtV3Timestamp0 = new BN('1632453299')
  const ethUsdtV3TickCum0 = new BN('-2406882279470') // From the V3 ETH/USDT pool
  const ethUsdtV3Timestamp1 = new BN('1632453899')
  const ethUsdtV3TickCum1 = new BN('-2406999836487')

  const usdcEthTokenToPrice = new BN(1)
  const usdcEthDecimals = new BN(-12)
  const usdcEthV3Timestamp0 = new BN('1632203136')
  const usdcEthV3TickCum0 = new BN('2357826690419') // From the V3 USDC/ETH pool
  const usdcEthV3Timestamp1 = new BN('1632203736')
  const usdcEthV3TickCum1 = new BN('2357944474677')

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
    let chainlinkAggregator, usdcEthPair

    beforeEach(async () => {
      chainlinkAggregator = await Aggregator.new({ from: deployer })
      await chainlinkAggregator.set(chainlinkPrice, chainlinkTime)

      usdcEthPool = await UniswapV3Pool.new({ from: deployer })
      await usdcEthPool.setObservation(ZERO, usdcEthV3Timestamp0, usdcEthV3TickCum0)
      await usdcEthPool.setObservation(ONE, usdcEthV3Timestamp1, usdcEthV3TickCum1)

      ethUsdtPool = await UniswapV3Pool.new({ from: deployer })
      await ethUsdtPool.setObservation(ZERO, ethUsdtV3Timestamp0, ethUsdtV3TickCum0)
      await ethUsdtPool.setObservation(ONE, ethUsdtV3Timestamp1, ethUsdtV3TickCum1)

      rawOracle = await MedianOracle.new(chainlinkAggregator.address,
        usdcEthPool.address, usdcEthTokenToPrice, usdcEthDecimals,
        ethUsdtPool.address, ethUsdtTokenToPrice, ethUsdtDecimals, { from: deployer })
      oracle = await GasMeasuredOracleWrapper.new(rawOracle.address, "median", { from: deployer })
      await oracle.refreshPrice()
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
      const uniswapPrice1 = (await rawOracle.latestUniswapV3TWAPPrice1())[0]
      const uniswapPrice2 = (await rawOracle.latestUniswapV3TWAPPrice2())[0]
      const targetOraclePrice = median(chainlinkPriceWAD, uniswapPrice1, uniswapPrice2)
      //console.log("Prices: oracle " + fl(oraclePrice) + ", target " + fl(targetOraclePrice) + ", Chainlink " + fl((await rawOracle.latestChainlinkPrice())[0]) + ", Uniswap1 " + fl(uniswapPrice1) + ", Uniswap2 " + fl(uniswapPrice2))
      oraclePrice.toString().should.equal(targetOraclePrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPrice())[0]
    })
  })
})
