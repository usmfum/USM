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
const GasUniswapTWAPOracle = artifacts.require('GasMeasuredOurUniswapV2TWAPOracle')

const GasUniswapMedianSpotOracle = artifacts.require('GasMeasuredUniswapMedianSpotOracle')
const GasUniswapMedianTWAPOracle = artifacts.require('GasMeasuredUniswapMedianTWAPOracle')

const GasMedianOracle = artifacts.require('GasMeasuredMedianOracle')

require('chai').use(require('chai-as-promised')).should()

contract('Oracle pricing', (accounts) => {
  const testPriceWAD = '250000000000000000000'              // TestOracle just uses WAD (18-dec-place) pricing

  const makerPriceWAD = '392110000000000000000'             // Maker medianizer (IMakerPriceFeed) returns WAD 18-dec-place prices

  const chainlinkPrice = '38598000000'                      // Chainlink aggregator (AggregatorV3Interface) stores 8 dec places
  const chainlinkPriceWAD = new BN(chainlinkPrice + '0000000000') // We want 18 dec places, so add 10 0s

  const compoundPrice = '414174999'                         // Compound view (UniswapAnchoredView) stores 6 dec places
  const compoundPriceWAD = new BN(compoundPrice + '000000000000') // We want 18 dec places, so add 12 0s

  const ethDecimals = new BN(18)                            // See OurUniswapV2SpotOracle
  const usdtDecimals = new BN(6)
  const usdcDecimals = new BN(6)
  const daiDecimals = new BN(18)
  const uniswapCumPriceScalingFactor = (new BN(2)).pow(new BN(112))

  const ethUsdtReserve0 = new BN('646310144553926227215994') // From the ETH/USDT pair.  See OurUniswapV2SpotOracle
  const ethUsdtReserve1 = new BN('254384028636585')
  const ethUsdtCumPrice0_0 = new BN('30197009659458262808281833965635')
  const ethUsdtCumPrice1_0 = new BN('276776388531768266239160661937116320880685460468473')
  const ethUsdtTimestamp_0 = new BN('1606780564')
  const ethUsdtCumPrice0_1 = new BN('30198349396553956234684790868151')
  const ethUsdtCumPrice1_1 = new BN('276779938284455484990752289414970402581013223198265')
  const ethUsdtTimestamp_1 = new BN('1606780984')
  const ethUsdtTokensInReverseOrder = false
  const ethUsdtScaleFactor = (new BN(10)).pow(ethDecimals.add(new BN(18)).sub(usdtDecimals))

  const usdcEthReserve0 = new BN('260787673159143')         // From the USDC/ETH pair
  const usdcEthReserve1 = new BN('696170744128378724814084')
  const usdcEthCumPrice0_0 = new BN('307631784275278277546624451305316303382174855535226')
  const usdcEthCumPrice1_0 = new BN('31377639132666967530700283664103')
  const usdcEthTimestamp_0 = new BN('1606780664')
  const usdcEthCumPrice0_1 = new BN('307634635050611880719301156089846577363471806696356')
  const usdcEthCumPrice1_1 = new BN('31378725947216452626380862836246')
  const usdcEthTimestamp_1 = new BN('1606781003')
  const usdcEthTokensInReverseOrder = true
  const usdcEthScaleFactor = (new BN(10)).pow(ethDecimals.add(new BN(18)).sub(usdcDecimals))

  const daiEthReserve0 = new BN('178617913077721329213551886') // From the DAI/ETH pair
  const daiEthReserve1 = new BN('480578265664207487333589')
  const daiEthCumPrice0_0 = new BN('291033362911607134656453476145906896216')
  const daiEthCumPrice1_0 = new BN('30339833685805974401597062880404438583745289')
  const daiEthTimestamp_0 = new BN('1606780728')
  const daiEthCumPrice0_1 = new BN('291036072023637413832938851532265880018')
  const daiEthCumPrice1_1 = new BN('30340852730044753766501469633003499944051151')
  const daiEthTimestamp_1 = new BN('1606781048')
  const daiEthTokensInReverseOrder = true
  const daiEthScaleFactor = (new BN(10)).pow(ethDecimals.add(new BN(18)).sub(daiDecimals))

  function median(a, b, c) {
    const ab = a > b
    const bc = b > c
    const ca = c > a
    return (ca == ab ? a : (ab == bc ? b : c))
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = (x.gt(y) ? x.sub(y) : y.sub(x))
    diff.should.be.bignumber.lt(x.add(y).div(new BN(1000000)))
  }

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
      oraclePrice.toString().should.equal(chainlinkPriceWAD.toString())
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
      oraclePrice.toString().should.equal(compoundPriceWAD.toString())
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
      await pair.setReserves(ethUsdtReserve0, ethUsdtReserve1, 0)

      oracle = await GasUniswapSpotOracle.new(pair.address, ethDecimals, usdtDecimals, ethUsdtTokensInReverseOrder,
                                              { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      const targetPrice = ethUsdtReserve1.mul(ethUsdtScaleFactor).div(ethUsdtReserve0) // reverseOrder = false
      oraclePrice.toString().should.equal(targetPrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with OurUniswapV2TWAPOracle", () => {
    const [deployer] = accounts
    let oracle
    let pair

    beforeEach(async () => {
      pair = await UniswapV2Pair.new({ from: deployer })
      await pair.setReserves(ethUsdtReserve0, ethUsdtReserve1, ethUsdtTimestamp_0)
      await pair.setCumulativePrices(ethUsdtCumPrice0_0, ethUsdtCumPrice1_0)

      oracle = await GasUniswapTWAPOracle.new(pair.address, ethDecimals, usdtDecimals, ethUsdtTokensInReverseOrder,
                                              { from: deployer })
      await oracle.cacheLatestPrice()

      await pair.setReserves(ethUsdtReserve0, ethUsdtReserve1, ethUsdtTimestamp_1)
      await pair.setCumulativePrices(ethUsdtCumPrice0_1, ethUsdtCumPrice1_1)
      //await oracle.cacheLatestPrice() // Not actually needed, unless we do further testing moving timestamps further forward
    })

    it('returns the correct price', async () => {
      const oraclePrice1 = (await oracle.latestPrice())

      const targetOraclePriceNum = (ethUsdtCumPrice0_1.sub(ethUsdtCumPrice0_0)).mul(ethUsdtScaleFactor)
      const targetOraclePriceDenom = (ethUsdtTimestamp_1.sub(ethUsdtTimestamp_0)).mul(uniswapCumPriceScalingFactor)
      const targetOraclePrice1 = targetOraclePriceNum.div(targetOraclePriceDenom)
      oraclePrice1.toString().should.equal(targetOraclePrice1.toString())
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
      await ethUsdtPair.setReserves(ethUsdtReserve0, ethUsdtReserve1, 0)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(usdcEthReserve0, usdcEthReserve1, 0)

      daiEthPair = await UniswapV2Pair.new({ from: deployer })
      await daiEthPair.setReserves(daiEthReserve0, daiEthReserve1, 0)

      oracle = await GasUniswapMedianSpotOracle.new(
          [ethUsdtPair.address, usdcEthPair.address, daiEthPair.address],
          [ethDecimals, usdcDecimals, daiDecimals],
          [usdtDecimals, ethDecimals, ethDecimals],
          [ethUsdtTokensInReverseOrder, usdcEthTokensInReverseOrder, daiEthTokensInReverseOrder], { from: deployer })
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      // Of the three pairs, the USDC/ETH pair has the middle price, so UniswapMedianSpotOracle's price should match it:
      const targetPrice = usdcEthReserve0.mul(usdcEthScaleFactor).div(usdcEthReserve1) // reverseOrder = true
      oraclePrice.toString().should.equal(targetPrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with UniswapMedianTWAPOracle", () => {
    const [deployer] = accounts
    let oracle
    let ethUsdtPair, usdcEthPair, daiEthPair

    beforeEach(async () => {
      ethUsdtPair = await UniswapV2Pair.new({ from: deployer })
      await ethUsdtPair.setReserves(ethUsdtReserve0, ethUsdtReserve1, ethUsdtTimestamp_0)
      await ethUsdtPair.setCumulativePrices(ethUsdtCumPrice0_0, ethUsdtCumPrice1_0)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(usdcEthReserve0, usdcEthReserve1, usdcEthTimestamp_0)
      await usdcEthPair.setCumulativePrices(usdcEthCumPrice0_0, usdcEthCumPrice1_0)

      daiEthPair = await UniswapV2Pair.new({ from: deployer })
      await daiEthPair.setReserves(daiEthReserve0, daiEthReserve1, daiEthTimestamp_0)
      await daiEthPair.setCumulativePrices(daiEthCumPrice0_0, daiEthCumPrice1_0)

      oracle = await GasUniswapMedianTWAPOracle.new(
          [ethUsdtPair.address, usdcEthPair.address, daiEthPair.address],
          [ethDecimals, usdcDecimals, daiDecimals],
          [usdtDecimals, ethDecimals, ethDecimals],
          [ethUsdtTokensInReverseOrder, usdcEthTokensInReverseOrder, daiEthTokensInReverseOrder], { from: deployer })
      await oracle.cacheLatestPrice()

      await ethUsdtPair.setReserves(ethUsdtReserve0, ethUsdtReserve1, ethUsdtTimestamp_1)
      await ethUsdtPair.setCumulativePrices(ethUsdtCumPrice0_1, ethUsdtCumPrice1_1)
      await usdcEthPair.setReserves(usdcEthReserve0, usdcEthReserve1, usdcEthTimestamp_1)
      await usdcEthPair.setCumulativePrices(usdcEthCumPrice0_1, usdcEthCumPrice1_1)
      await daiEthPair.setReserves(daiEthReserve0, daiEthReserve1, daiEthTimestamp_1)
      await daiEthPair.setCumulativePrices(daiEthCumPrice0_1, daiEthCumPrice1_1)
      //await oracle.cacheLatestPrice() // Not actually needed, unless we do further testing moving timestamps further forward
    })

    it('returns the correct price', async () => {
      const ethUsdtPrice1 = (await oracle.latestUniswapPair1TWAPPrice())
      const targetEthUsdtPriceNum = (ethUsdtCumPrice0_1.sub(ethUsdtCumPrice0_0)).mul(ethUsdtScaleFactor)
      const targetEthUsdtPriceDenom = (ethUsdtTimestamp_1.sub(ethUsdtTimestamp_0)).mul(uniswapCumPriceScalingFactor)
      const targetEthUsdtPrice1 = targetEthUsdtPriceNum.div(targetEthUsdtPriceDenom)
      shouldEqualApprox(ethUsdtPrice1, targetEthUsdtPrice1)

      const usdcEthPrice1 = (await oracle.latestUniswapPair2TWAPPrice())
      const targetUsdcEthPriceNum = (usdcEthCumPrice1_1.sub(usdcEthCumPrice1_0)).mul(usdcEthScaleFactor)
      const targetUsdcEthPriceDenom = (usdcEthTimestamp_1.sub(usdcEthTimestamp_0)).mul(uniswapCumPriceScalingFactor)
      const targetUsdcEthPrice1 = targetUsdcEthPriceNum.div(targetUsdcEthPriceDenom)
      shouldEqualApprox(usdcEthPrice1, targetUsdcEthPrice1)

      const daiEthPrice1 = (await oracle.latestUniswapPair3TWAPPrice())
      const targetDaiEthPriceNum = (daiEthCumPrice1_1.sub(daiEthCumPrice1_0)).mul(daiEthScaleFactor)
      const targetDaiEthPriceDenom = (daiEthTimestamp_1.sub(daiEthTimestamp_0)).mul(uniswapCumPriceScalingFactor)
      const targetDaiEthPrice1 = targetDaiEthPriceNum.div(targetDaiEthPriceDenom)
      shouldEqualApprox(daiEthPrice1, targetDaiEthPrice1)

      const oraclePrice1 = (await oracle.latestPrice())
      const targetOraclePrice1 = median(ethUsdtPrice1, usdcEthPrice1, daiEthPrice1)
      oraclePrice1.toString().should.equal(targetOraclePrice1.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })

  describe("with MedianOracle", () => {
    const [deployer] = accounts
    let oracle
    let makerMedianizer, chainlinkAggregator, compoundView, usdcEthPair

    beforeEach(async () => {
      //makerMedianizer = await Medianizer.new({ from: deployer })
      //await makerMedianizer.set(makerPriceWAD)

      chainlinkAggregator = await Aggregator.new({ from: deployer })
      await chainlinkAggregator.set(chainlinkPrice)

      compoundView = await UniswapAnchoredView.new({ from: deployer })
      await compoundView.set(compoundPrice)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(usdcEthReserve0, usdcEthReserve1, usdcEthTimestamp_0)
      await usdcEthPair.setCumulativePrices(usdcEthCumPrice0_0, usdcEthCumPrice1_0)

      oracle = await GasMedianOracle.new(chainlinkAggregator.address, compoundView.address,
        usdcEthPair.address, usdcDecimals, ethDecimals, usdcEthTokensInReverseOrder, { from: deployer })
      await oracle.cacheLatestPrice()

      await usdcEthPair.setReserves(usdcEthReserve0, usdcEthReserve1, usdcEthTimestamp_1)
      await usdcEthPair.setCumulativePrices(usdcEthCumPrice0_1, usdcEthCumPrice1_1)
      //await oracle.cacheLatestPrice() // Not actually needed, unless we do further testing moving timestamps further forward
    })

    it('returns the correct price', async () => {
      const oraclePrice = (await oracle.latestPrice())
      const uniswapPrice = (await oracle.latestUniswapTWAPPrice())
      const targetOraclePrice = median(chainlinkPriceWAD, compoundPriceWAD, uniswapPrice)
      oraclePrice.toString().should.equal(targetOraclePrice.toString())
    })

    it('returns the price in a transaction', async () => {
      const oraclePrice = (await oracle.latestPriceWithGas())
    })
  })
})
