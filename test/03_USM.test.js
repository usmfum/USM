const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')
const timeMachine = require('ganache-time-traveler')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
const CompoundUniswapAnchoredView = artifacts.require('MockCompoundUniswapAnchoredView')
const UniswapV2Pair = artifacts.require('MockUniswapV2Pair')

const WadMath = artifacts.require('MockWadMath')
const MedianOracle = artifacts.require('MockMedianOracle')
const USM = artifacts.require('USM')
const FUM = artifacts.require('FUM')
const USMView = artifacts.require('USMView')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  const [deployer, user1, user2, user3, optOut1, optOut2] = accounts
  const [ZERO, ONE, TWO, FOUR, SIX, EIGHT, TEN, EIGHTEEN, HUNDRED, THOUSAND, WAD] =
        [0, 1, 2, 4, 6, 8, 10, 18, 100, 1000, '1000000000000000000'].map(function (n) { return new BN(n) })
  const WAD_MINUS_1 = WAD.sub(ONE)
  const sides = { BUY: 0, SELL: 1 }
  const oneEth = WAD
  const oneUsm = WAD
  const oneFum = WAD
  const MINUTE = 60
  const HOUR = 60 * MINUTE
  const DAY = 24 * HOUR

  const prefundFumPrice = WAD.div(new BN(4000))
  let priceWAD
  let oneDollarInEth
  const shift = '18'

  let aggregator
  const chainlinkPrice = '38598000000'                      // 8 dec places: see ChainlinkOracle
  const chainlinkTime = '1613550219'                        // Timestamp ("updatedAt") of the Chainlink price

  let anchoredView
  const compoundPrice = '414174999'                         // 6 dec places: see CompoundOpenOracle

  let usdcEthPair
  const usdcEthTokenToUse = new BN(1)                       // See OurUniswapV2TWAPOracle for explanations of these
  const usdcEthCumPrice1_0 = new BN('31375939132666967530700283664103')     // From the USDC/ETH pair
  const usdcEthTimestamp_0 = new BN('1606780664')
  const usdcEthCumPrice1_1 = new BN('31378725947216452626380862836246')
  const usdcEthTimestamp_1 = new BN('1606782003')
  const usdcEthEthDecimals = new BN(-12)

  let MAX_DEBT_RATIO

  function checkUsmBuyAndSellPrices(ethUsdMidPrice, bidAskAdj, usmBuyPrice, usmSellPrice) {
    const ethUsdSellPrice = bidAskAdjustedEthUsdPrice(fl(ethUsdMidPrice), fl(bidAskAdj), sides.SELL)
    const targetUsmBuyPrice = 1 / ethUsdSellPrice
    shouldEqualApprox(usmBuyPrice, wad(targetUsmBuyPrice))

    const ethUsdBuyPrice = bidAskAdjustedEthUsdPrice(fl(ethUsdMidPrice), fl(bidAskAdj), sides.BUY)
    const targetUsmSellPrice = 1 / ethUsdBuyPrice
    shouldEqualApprox(usmSellPrice, wad(targetUsmSellPrice))
  }

  function checkFumBuyAndSellPrices(ethUsdMidPrice, bidAskAdj, ethQty, usmQty, fumQty, debtRatio, fumBuyPrice, fumSellPrice) {
    if (fl(debtRatio) <= fl(MAX_DEBT_RATIO)) {  // If dr > MAX, minFumBuyPrice kicks in so our simple math here doesn't apply
      const ethUsdBuyPrice = bidAskAdjustedEthUsdPrice(fl(ethUsdMidPrice), fl(bidAskAdj), sides.BUY)
      const targetFumBuyPrice = fumPrice(ethUsdBuyPrice, fl(ethQty), fl(usmQty), fl(fumQty))
      shouldEqualApprox(fumBuyPrice, wad(targetFumBuyPrice))
    }

    const ethUsdSellPrice = bidAskAdjustedEthUsdPrice(fl(ethUsdMidPrice), fl(bidAskAdj), sides.SELL)
    const targetFumSellPrice = fumPrice(ethUsdSellPrice, fl(ethQty), fl(usmQty), fl(fumQty))
    shouldEqualApprox(fumSellPrice, wad(targetFumSellPrice))
  }

  function fumPrice(effectiveEthUsdPrice, ethQty, usmQty, fumQty) {
    // Math.max(0, ...) because sometimes fumSellPrice is negative, in which case we floor it at 0:
    return Math.max(0, (ethQty - usmQty / effectiveEthUsdPrice) / fumQty)
  }

  function bidAskAdjustedEthUsdPrice(ethUsdMidPrice, bidAskAdj, side) {
    return ethUsdMidPrice * (side == sides.BUY ? Math.max(1, bidAskAdj) : Math.min(1, bidAskAdj))
  }

  function wadMul(x, y, roundUp) {
      return ((x.mul(y)).add(roundUp ? WAD_MINUS_1 : ZERO)).div(WAD)
  }

  function wadSquared(x) {
    return wadMul(x, x)
  }

  function wadDiv(x, y, upOrDown) {
    return ((x.mul(WAD)).add(y.sub(ONE))).div(y)
  }

  function wadSqrtDown(y) {
    y = y.mul(WAD)
    if (y.gt(THREE)) {
      let z = y
      let x = y.div(TWO).add(ONE)
      while (x.lt(z)) {
        z = x
        x = y.div(x).add(x).div(TWO)
      }
      return z
    } else if (y.ne(ZERO)) {
      return ONE
    }
    return ZERO
  }

  function wadSqrtUp(y) {
    if (y.eq(ZERO)) {
      return ZERO
    } else {
      return wadSqrtDown(y.sub(ONE)).add(ONE)
    }
  }

  function wadDecay(adjustment, decayFactor) {
    return WAD.add(wadMul(adjustment, decayFactor, false)).sub(decayFactor)
  }

  function shouldEqual(x, y) {
    x.toString().should.equal(y.toString())
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = x.sub(y).abs()
    diff.should.be.bignumber.lte(x.add(y).abs().div(new BN(1000000)))
  }

  function fl(w) { // Converts a WAD fixed-point (eg, 2.7e18) to an unscaled float (2.7).  Of course may lose a bit of precision
    return parseFloat(w) / WAD
  }

  // Converts a JavaScript Number to a BN (bignumber).  May lose some precision for large numbers, but at least the approach
  // here, via BigInts, isn't totally broken like the simple new BN(x), or new BN(x.toString()).  Eg:
  // x = 10**23
  // x.toString()                          -> "1e+23"
  // new BN(x)                             -> fails with "Error: Assertion failed" (?)
  // new BN(x.toString())                  -> 23523 (??)
  // bn(x) = new BN(BigInt(Math.round(x))) -> 99999999999999991611392 (imperfect precision, but at least in the ballpark)
  function bn(x) {
    return new BN(BigInt(Math.round(parseFloat(x))))
  }

  function wad(x) {
    return new BN(BigInt(Math.round(parseFloat(x) * WAD)))
  }

  // ____________________ Deployment ____________________

  describe("mints and burns a static amount", () => {
    let oracle, usm, fum, usmView, ethPerFund, ethPerMint, bitOfEth, snapshot, snapshotId

    beforeEach(async () => {
      // Oracle params

      aggregator = await Aggregator.new({ from: deployer })
      await aggregator.set(chainlinkPrice, chainlinkTime)

      anchoredView = await CompoundUniswapAnchoredView.new({ from: deployer })
      await anchoredView.set(compoundPrice)

      usdcEthPair = await UniswapV2Pair.new({ from: deployer })
      await usdcEthPair.setReserves(0, 0, usdcEthTimestamp_0)
      await usdcEthPair.setCumulativePrices(0, usdcEthCumPrice1_0)

      // USM
      oracle = await MedianOracle.new(aggregator.address, anchoredView.address,
                                      usdcEthPair.address, usdcEthTokenToUse, usdcEthEthDecimals,
                                      { from: deployer })
      usm = await USM.new(oracle.address, [optOut1, optOut2], { from: deployer })
      await usm.refreshPrice()  // This call stores the Uniswap cumPriceSeconds record for time usdcEthTimestamp_0
      fum = await FUM.at(await usm.fum())
      usmView = await USMView.new(usm.address, { from: deployer })

      await usdcEthPair.setReserves(0, 0, usdcEthTimestamp_1)
      await usdcEthPair.setCumulativePrices(0, usdcEthCumPrice1_1)
      await usm.refreshPrice()  // ...And this stores the cumPriceSeconds for usdcEthTimestamp_1 - so we have a valid TWAP now

      priceWAD = (await usm.latestPrice())[0]
      oneDollarInEth = wadDiv(WAD, priceWAD, true)

      ethPerFund = oneEth.mul(FOUR)     // Can be any (?) number
      ethPerMint = oneEth.mul(TWO)      // Can be any (?) number (though < ethPerFund nice, so fumSellPrice isn't pushed to 0)
      bitOfEth = oneEth.div(THOUSAND)

      snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']
    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe("deployment", () => {
      it("starts with correct FUM price", async () => {
        const fumBuyPrice = await usmView.fumPrice(sides.BUY)
        // The FUM price should start off equal to $1, in ETH terms = 1 / price:
        shouldEqualApprox(fumBuyPrice, prefundFumPrice)

        const fumSellPrice = await usmView.fumPrice(sides.SELL)
        shouldEqualApprox(fumSellPrice, prefundFumPrice)
      })
    })

    // ____________________ Minting and burning ____________________

    describe("minting and burning", () => {
      beforeEach(async () => {
        MAX_DEBT_RATIO = await usm.MAX_DEBT_RATIO()
      })

      it("doesn't allow minting USM before minting FUM", async () => {
        await expectRevert(usm.mint(user1, 0, { from: user2, value: ethPerMint }), "Fund before minting")
      })

      it("allows minting FUM (at flat price)", async () => {
        const price0 = (await usm.latestPrice())[0]

        await usm.fund(user2, 0, { from: user1, value: ethPerFund })

        // Uses flat FUM price until USM is minted
        const ethPool = await usm.ethPool()
        const targetEthPool = ethPerFund
        shouldEqual(ethPool, targetEthPool)

        // Check that the FUM created was just based on straight linear pricing, ETH qty / price:
        const user2FumBalance = await fum.balanceOf(user2)
        const targetTotalFumSupply = wadDiv(ethPerFund, prefundFumPrice, false)
        shouldEqualApprox(user2FumBalance, targetTotalFumSupply)    // Only approx b/c fumFromFund() loses some precision
        const totalFumSupply = await fum.totalSupply()
        shouldEqualApprox(totalFumSupply, targetTotalFumSupply)

        // And relatedly, bidAskAdjustment should be unchanged (1), and FUM buy price and FUM sell price should still be $1:
        const bidAskAdj = await usm.bidAskAdjustment()
        shouldEqual(bidAskAdj, WAD)
        const price = (await usm.latestPrice())[0]
        shouldEqual(price, price0)

        const usmBuyPrice = await usmView.usmPrice(sides.BUY)
        shouldEqualApprox(usmBuyPrice, oneDollarInEth)
        const usmSellPrice = await usmView.usmPrice(sides.SELL)
        shouldEqualApprox(usmSellPrice, oneDollarInEth)

        const fumBuyPrice = await usmView.fumPrice(sides.BUY)
        shouldEqualApprox(fumBuyPrice, prefundFumPrice)
        const fumSellPrice = await usmView.fumPrice(sides.SELL)
        shouldEqualApprox(fumSellPrice, prefundFumPrice)
      })

      describe("with existing FUM supply", () => {
        beforeEach(async () => {
          await usm.fund(user2, 0, { from: user1, value: ethPerFund })
        })

        it("allows minting USM", async () => {
          await usm.mint(user1, 0, { from: user2, value: ethPerMint })
        })

        describe("with existing USM supply", () => {
          let ethPool0, price0, debtRatio0, user1UsmBalance0, totalUsmSupply0, user2FumBalance0, totalFumSupply0, bidAskAdj0,
              fumBuyPrice0, fumSellPrice0, usmBuyPrice0, usmSellPrice0

          beforeEach(async () => {
            await usm.mint(user1, 0, { from: user2, value: ethPerMint })

            // Move forward 60 days, so bidAskAdj reverts to 1 (ie no adj), and we're past the prefund period (no fixed price):
            const block0 = await web3.eth.getBlockNumber()
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 60 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = await web3.eth.getBlockNumber()
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            shouldEqual(t1, t0 + timeDelay)

            ethPool0 = await usm.ethPool()                      // "0" suffix = initial values (after first fund() + mint())
            price0 = (await usm.latestPrice())[0]
            debtRatio0 = await usmView.debtRatio()
            user1UsmBalance0 = await usm.balanceOf(user1)
            totalUsmSupply0 = await usm.totalSupply()
            user2FumBalance0 = await fum.balanceOf(user2)
            totalFumSupply0 = await fum.totalSupply()
            bidAskAdj0 = await usm.bidAskAdjustment()
            fumBuyPrice0 = await usmView.fumPrice(sides.BUY)
            fumSellPrice0 = await usmView.fumPrice(sides.SELL)
            usmBuyPrice0 = await usmView.usmPrice(sides.BUY)
            usmSellPrice0 = await usmView.usmPrice(sides.SELL)
          })

          // ____________________ Minting FUM (aka fund()) ____________________

          it("calculates log/exp correctly", async () => {
            const w = await WadMath.new()
            const a = new BN('987654321098765432')    //  0.987654321098765432
            const b = new BN('12345678901234567890')  // 12.345678901234567890

            const expDownA = await w.wadExpDown(a)
            const expUpA = await w.wadExpUp(a)
            const targetExpA = wad(Math.exp(fl(a)))
            shouldEqualApprox(expDownA, targetExpA)
            shouldEqualApprox(expUpA, targetExpA)
            const expDownB = await w.wadExpDown(b)
            const expUpB = await w.wadExpUp(b)
            const targetExpB = wad(Math.exp(fl(b)))
            shouldEqualApprox(expDownB, targetExpB)
            shouldEqualApprox(expUpB, targetExpB)

            const expDownAB = await w.wadPowDown(a, b)
            const expUpAB = await w.wadPowUp(a, b)
            const targetExpAB = wad(fl(a)**fl(b))
            shouldEqualApprox(expDownAB, targetExpAB)
            shouldEqualApprox(expUpAB, targetExpAB)
            const expDownBA = await w.wadPowDown(b, a)
            const expUpBA = await w.wadPowUp(b, a)
            const targetExpBA = wad(fl(b)**fl(a))
            shouldEqualApprox(expDownBA, targetExpBA)
            shouldEqualApprox(expUpBA, targetExpBA)
          })

          it("allows minting FUM (at sliding price)", async () => {
            await usm.fund(user2, 0, { from: user1, value: ethPerFund })
          })

          describe("with FUM minted at sliding price", () => {
            let ethPoolF, priceF, debtRatioF, user2FumBalanceF, totalFumSupplyF, bidAskAdjF, fumBuyPriceF, fumSellPriceF,
                usmBuyPriceF, usmSellPriceF, effectiveUsmQty0, adjGrowthFactorF

            beforeEach(async () => {
              await usm.fund(user2, 0, { from: user1, value: ethPerFund })

              ethPoolF = await usm.ethPool()                    // "F" suffix = values after this fund() call
              priceF = (await usm.latestPrice())[0]
              debtRatioF = await usmView.debtRatio()
              user2FumBalanceF = await fum.balanceOf(user2)
              totalFumSupplyF = await fum.totalSupply()
              bidAskAdjF = await usm.bidAskAdjustment()
              fumBuyPriceF = await usmView.fumPrice(sides.BUY)
              fumSellPriceF = await usmView.fumPrice(sides.SELL)
              usmBuyPriceF = await usmView.usmPrice(sides.BUY)
              usmSellPriceF = await usmView.usmPrice(sides.SELL)

              // See USMTemplate.fumFromFund() for the math we're mirroring here:
              const effectiveDebtRatio0 = Math.min(fl(debtRatio0), fl(MAX_DEBT_RATIO))
              const netFumDelta = effectiveDebtRatio0 / (1 - effectiveDebtRatio0)
              adjGrowthFactorF = (fl(ethPoolF) / fl(ethPool0))**(netFumDelta / 2)
            })

            it("calculates sqrt correctly", async () => {
              const roots = [1, 2, 3, 7, 10, 99, 1001, 10000, 99999, 1000001]
              const w = await WadMath.new()
              let i, r, square, sqrt
              for (i = 0; i < roots.length; ++i) {
                r = (new BN(roots[i])).mul(WAD)
                square = wadSquared(r)
                sqrt = await w.wadSqrtDown(square)
                sqrt.should.be.bignumber.lte(r) // wadSqrtDown(49000000000000000000) should return <= 7000000000000000000
                sqrt = await w.wadSqrtUp(square)
                sqrt.should.be.bignumber.gte(r) // wadSqrtUp(49000000000000000000) should return >= 7000000000000000000
                sqrt = await w.wadSqrtDown(square.add(ONE))
                sqrt.should.be.bignumber.lte(r) // wadSqrtDown(49000000000000000001) should return <= 7000000000000000000 too
                sqrt = await w.wadSqrtUp(square.add(ONE))
                sqrt.should.be.bignumber.gt(r)  // wadSqrtUp(49000000000000000001) should return *>* 7000000000000000000 (ie, round up)
                sqrt = await w.wadSqrtDown(square.sub(ONE))
                sqrt.should.be.bignumber.lt(r)  // wadSqrtDown(48999999999999999999) should return *<* 6999999999999999999 (ie, round down)
                sqrt = await w.wadSqrtUp(square.sub(ONE))
                sqrt.should.be.bignumber.gte(r) // wadSqrtUp(48999999999999999999) should return >= 7000000000000000000 (ie, round up)
              }
            })

            it("increases ETH pool correctly when minting FUM", async () => {
              const targetEthPoolF = ethPool0.add(ethPerFund)
              shouldEqual(ethPoolF, targetEthPoolF)
            })

            it("increases bidAskAdjustment correctly when minting FUM", async () => {
              bidAskAdjF.should.be.bignumber.gt(bidAskAdj0)
              const targetBidAskAdjF = wad(fl(bidAskAdj0) * adjGrowthFactorF)
              shouldEqualApprox(bidAskAdjF, targetBidAskAdjF)
            })

            it("increases ETH mid price correctly when minting FUM", async () => {
              const targetPriceF = wad(fl(price0) * adjGrowthFactorF)
              shouldEqualApprox(priceF, targetPriceF)
            })

            it("increases FUM buy and sell prices correctly when minting FUM", async () => {
              // Minting FUM 1. pushes ETH mid price up 2. pushes bidAskAdj up and 3. collects fees for FUM holders.  All three
              // of these are bad for FUM buyers/minters (fumBuyPrice up), and good for FUM sellers/burners (fumSellPrice up):
              fumBuyPriceF.should.be.bignumber.gt(fumBuyPrice0)
              fumSellPriceF.should.be.bignumber.gte(fumSellPrice0)  // gte b/c fumSellPrice is floored at 0, so both might be 0

              checkFumBuyAndSellPrices(priceF, bidAskAdjF, ethPoolF, totalUsmSupply0, totalFumSupplyF, debtRatioF,
                                       fumBuyPriceF, fumSellPriceF)
            })

            it("reduces USM buy and sell prices when minting FUM", async () => {
              // Minting FUM both 1. pushes ETH mid price up and 2. pushes bidAskAdj up.  Both of these are good for USM
              // buyers/minters (usmBuyPrice down), and bad for USM sellers/burners (usmSellPrice down):
              usmBuyPriceF.should.be.bignumber.lt(usmBuyPrice0)
              usmSellPriceF.should.be.bignumber.lt(usmSellPrice0)

              checkUsmBuyAndSellPrices(priceF, bidAskAdjF, usmBuyPriceF, usmSellPriceF)
            })

            it("increases FUM supply correctly when minting FUM", async () => {
              // Math from USMTemplate.fumFromFund():
              const adjustedEthUsdPrice0 = bidAskAdjustedEthUsdPrice(fl(price0), fl(bidAskAdj0), sides.BUY)
              const adjustedEthUsdPrice1 = adjustedEthUsdPrice0 * adjGrowthFactorF**2
              const fumBuyPrice1 = fumPrice(adjustedEthUsdPrice1, fl(ethPool0), fl(totalUsmSupply0), fl(totalFumSupply0))
              const avgFumBuyPrice = (fl(fumBuyPrice0) * fumBuyPrice1)**0.5
              const fumOut = fl(ethPerFund) / avgFumBuyPrice
              const targetTotalFumSupplyF = wad(fl(totalFumSupply0) + fumOut)
              shouldEqualApprox(user2FumBalanceF, targetTotalFumSupplyF)
              shouldEqualApprox(totalFumSupplyF, targetTotalFumSupplyF)
            })

            it("reduces debtRatio when minting FUM", async () => {
              debtRatioF.should.be.bignumber.lt(debtRatio0)
            })

            it("decays bidAskAdjustment over time", async () => {
              // Check that bidAskAdjustment decays properly (well, approximately) over time:
              // - Start with an adjustment j != 1.
              // - Use timeMachine to move forward 180 secs = 3 min.
              // - Since USM.BID_ASK_ADJUSTMENT_HALF_LIFE = 60 (1 min), 3 min should mean a decay of ~1/8.
              // - The way our "time decay towards 1" approximation works, decaying j by ~1/8 should yield 1 + (j * 1/8) - 1/8.
              //   (See comment in USM.bidAskAdjustment().)

              // Need bidAskAdj to be active (ie, != 1) for this test to be meaningful.  After fund() above it should be > 1:
              bidAskAdjF.should.be.bignumber.gt(bidAskAdj0)

              const block0 = await web3.eth.getBlockNumber()
              const t0 = (await web3.eth.getBlock(block0)).timestamp
              const timeDelay = 3 * MINUTE
              await timeMachine.advanceTimeAndBlock(timeDelay)
              const block1 = await web3.eth.getBlockNumber()
              const t1 = (await web3.eth.getBlock(block1)).timestamp
              shouldEqual(t1, t0 + timeDelay)

              const bidAskAdj = await usm.bidAskAdjustment()
              const decayFactor = wadDiv(ONE, EIGHT, false)
              const targetBidAskAdj = wadDecay(bidAskAdjF, decayFactor)
              shouldEqualApprox(bidAskAdj, targetBidAskAdj)
            })
          })

          it("reduces minFumBuyPrice over time", async () => {
            // Move price to get debt ratio just *above* MAX:
            //const targetDebtRatio1 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const targetDebtRatio1 = WAD    // 100%.  More is OK but between 80% and 100% makes the math below more complicated
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1, true)
            const targetPrice1 = wadMul(price0, priceChangeFactor1, false)
            await oracle.setPrice(targetPrice1)
            await usm.refreshPrice()    // Need to refreshPrice() after setPrice(), to get the new value into usm.storedPrice
            const price1 = (await usm.latestPrice())[0]
            shouldEqualApprox(price1, targetPrice1)

            const debtRatio1 = await usmView.debtRatio()
            debtRatio1.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // Move forward a day, so our bidAskAdj reverts to 1 (ie no adjustment):
            const block0 = await web3.eth.getBlockNumber()
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 1 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = await web3.eth.getBlockNumber()
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            shouldEqual(t1, t0 + timeDelay)

            // Make one tiny call to fund(), just to actually trigger the internal call to checkIfUnderwater(), with a mint()
            // before just so bidAskAdj doesn't end up > 1 (which would make our FUM buy price messier):
            await usm.mint(user1, 0, { from: user2, value: ethPerMint })
            await usm.fund(user3, 0, { from: user3, value: bitOfEth })

            // Calculate targetFumBuyPrice using the math in USM.checkIfUnderwater():
            //const targetFumBuyPrice2 = wadDiv(wadMul(WAD.sub(MAX_DEBT_RATIO), ethPool0, true), totalFumSupply0, true)
            const ethPool2 = await usm.ethPool()
            const price2 = (await usm.latestPrice())[0]
            const totalFumSupply2 = await fum.totalSupply()
            const poolValue2 = wadMul(ethPool2, price2, false)
            const usmForFumBuy2 = wadMul(poolValue2, MAX_DEBT_RATIO, false)
            const ethBuffer2 = ethPool2.sub(wadDiv(usmForFumBuy2, price2, false))
            const targetFumBuyPrice2 = wadDiv(ethBuffer2, totalFumSupply2, true)

            const fumBuyPrice2 = await usmView.fumPrice(sides.BUY)
            shouldEqualApprox(fumBuyPrice2, targetFumBuyPrice2)

            // Now move forward a few days, and check that fumBuyPrice decays by the appropriate factor:
            const block2 = await web3.eth.getBlockNumber()
            const t2 = (await web3.eth.getBlock(block2)).timestamp
            const timeDelay2 = 3 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay2)
            const block3 = await web3.eth.getBlockNumber()
            const t3 = (await web3.eth.getBlock(block3)).timestamp
            shouldEqual(t3, t2 + timeDelay2)

            //const targetFumBuyPrice3 = wadMul(fumBuyPrice2, decayFactor3, true)
            const decayFactor3 = wadDiv(ONE, EIGHT, true)   // aka 0.5**(timeDelay / MIN_FUM_BUY_PRICE_HALF_LIFE)
            const usmForFumBuy3 = poolValue2.sub(wadMul(decayFactor3, poolValue2.sub(usmForFumBuy2), false))
            const ethBuffer3 = ethPool2.sub(wadDiv(usmForFumBuy3, price2, false))
            const targetFumBuyPrice3 = wadDiv(ethBuffer3, totalFumSupply2, true)

            const fumBuyPrice3 = await usmView.fumPrice(sides.BUY)
            fumBuyPrice3.should.be.bignumber.lt(fumBuyPrice2)
            shouldEqualApprox(fumBuyPrice3, targetFumBuyPrice3)
          })

          it("sending Ether to the FUM contract mints (funds) FUM", async () => {
            await web3.eth.sendTransaction({ from: user2, to: fum.address, value: ethPerFund })

            // These checks are crude simplifications of the "with FUM minted at sliding price" checks above:
            const ethPool = await usm.ethPool()
            const targetEthPool = ethPool0.add(ethPerFund)
            shouldEqual(ethPool, targetEthPool)

            const bidAskAdj = await usm.bidAskAdjustment()
            bidAskAdj.should.be.bignumber.gt(bidAskAdj0)
            const price = (await usm.latestPrice())[0]
            price.should.be.bignumber.gt(price0)

            const user2FumBalance = await fum.balanceOf(user2)
            user2FumBalance.should.be.bignumber.gt(user2FumBalance0)
            const totalFumSupply = await fum.totalSupply()
            totalFumSupply.should.be.bignumber.gt(totalFumSupply0)
          })

          // ____________________ Minting USM (aka mint()), at sliding price ____________________

          describe("with USM minted at sliding price", () => {
            let ethPoolM, priceM, debtRatioM, user2FumBalanceM, totalFumSupplyM, bidAskAdjM, fumBuyPriceM, fumSellPriceM,
                usmBuyPriceM, usmSellPriceM, adjShrinkFactorM

            beforeEach(async () => {
              await usm.mint(user1, 0, { from: user2, value: ethPerMint })

              ethPoolM = await usm.ethPool()                    // "M" suffix = values after this mint() call
              priceM = (await usm.latestPrice())[0]
              debtRatioM = await usmView.debtRatio()
              user1UsmBalanceM = await usm.balanceOf(user1)
              totalUsmSupplyM = await usm.totalSupply()
              bidAskAdjM = await usm.bidAskAdjustment()
              fumBuyPriceM = await usmView.fumPrice(sides.BUY)
              fumSellPriceM = await usmView.fumPrice(sides.SELL)
              usmBuyPriceM = await usmView.usmPrice(sides.BUY)
              usmSellPriceM = await usmView.usmPrice(sides.SELL)

              adjShrinkFactorM = (fl(ethPool0) / fl(ethPoolM))**0.5
            })

            it("increases ETH pool correctly when minting USM", async () => {
              const targetEthPoolM = ethPool0.add(ethPerMint)
              shouldEqual(ethPoolM, targetEthPoolM)
            })

            it("reduces bidAskAdjustment correctly when minting USM", async () => {
              bidAskAdjM.should.be.bignumber.lt(bidAskAdj0)
              const targetBidAskAdjM = wad(fl(bidAskAdj0) * adjShrinkFactorM)
              shouldEqualApprox(bidAskAdjM, targetBidAskAdjM)
            })

            it("reduces ETH mid price correctly when minting USM", async () => {
              const targetPriceM = wad(fl(price0) * adjShrinkFactorM)
              shouldEqualApprox(priceM, targetPriceM)
            })

            it("increases USM buy and sell prices correctly when minting USM", async () => {
              // Minting USM 1. reduces ETH mid price and 2. reduces bidAskAdj - both bad for USM buyers, good for USM sellers:
              usmBuyPriceM.should.be.bignumber.gt(usmBuyPrice0)
              usmSellPriceM.should.be.bignumber.gt(usmSellPrice0)

              checkUsmBuyAndSellPrices(priceM, bidAskAdjM, usmBuyPriceM, usmSellPriceM)
            })

            it("reduces FUM buy and sell prices when minting USM", async () => {
              // Minting USM 1. reduces ETH mid price 2. reduces bidAskAdj and 3. collects fees for FUM holders.  1 and 2
              // reduce the FUM price, 3 increases it, so the net effect depends on how high the fees are (how big ethIn is
              // relative to ethPool).  So there's no simple rule for whether fumBuy/SellPrice increase or decrease here.

              checkFumBuyAndSellPrices(priceM, bidAskAdjM, ethPoolM, totalUsmSupplyM, totalFumSupply0, debtRatioM,
                                       fumBuyPriceM, fumSellPriceM)
            })

            it("increases USM supply correctly when minting USM", async () => {
              // Math from USMTemplate.usmFromMint():
              const avgUsmMintPrice = fl(usmBuyPrice0) / adjShrinkFactorM
              const targetUsmOut = wad(fl(ethPerMint) / avgUsmMintPrice)
              const targetTotalUsmSupplyM = totalUsmSupply0.add(targetUsmOut)

              shouldEqualApprox(user1UsmBalanceM, targetTotalUsmSupplyM)
              shouldEqualApprox(totalUsmSupplyM, targetTotalUsmSupplyM)
            })

            it("moves debtRatio towards 100% when minting USM", async () => {
              if (debtRatio0.lt(WAD)) {
                debtRatioM.should.be.bignumber.gt(debtRatio0)
              } else {
                debtRatioM.should.be.bignumber.lt(debtRatio0)
              }
            })
          })

          it("reduces bidAskAdjustment when minting while debt ratio > 100%", async () => {
            // Move price to get debt ratio just *above* 100%:
            const targetDebtRatio = WAD.mul(HUNDRED.add(ONE)).div(HUNDRED) // 101%
            const priceChangeFactor = wadDiv(debtRatio0, targetDebtRatio, true)
            const targetPrice = wadMul(price0, priceChangeFactor, false)
            await oracle.setPrice(targetPrice)
            await usm.refreshPrice()
            const price = (await usm.latestPrice())[0]
            shouldEqualApprox(price, targetPrice)

            const debtRatio = await usmView.debtRatio()
            debtRatio.should.be.bignumber.gt(WAD)

            // And now minting should still reduce the adjustment, not increase it:
            const bidAskAdj1 = await usm.bidAskAdjustment()
            await usm.mint(user1, 0, { from: user2, value: bitOfEth })
            const bidAskAdj2 = await usm.bidAskAdjustment()
            bidAskAdj2.should.be.bignumber.lt(bidAskAdj1)
          })

          it("sending Ether to the USM contract mints USM", async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: ethPerMint })

            // These checks are all cribbed from the "with USM minted at sliding price" checks above:
            const ethPool = await usm.ethPool()
            const targetEthPool = ethPool0.add(ethPerMint)
            shouldEqual(ethPool, targetEthPool)

            const bidAskAdj = await usm.bidAskAdjustment()
            const adjShrinkFactor = (fl(ethPool0) / fl(ethPool))**0.5
            const targetBidAskAdj = wad(fl(bidAskAdj0) * adjShrinkFactor)
            shouldEqualApprox(bidAskAdj, targetBidAskAdj)
            const price = (await usm.latestPrice())[0]
            const targetPrice = wad(fl(price0) * adjShrinkFactor)
            shouldEqualApprox(price, targetPrice)

            const user1UsmBalance = await usm.balanceOf(user1)
            const avgUsmMintPrice = fl(usmBuyPrice0) / adjShrinkFactor
            const targetUsmOut = wad(fl(ethPerMint) / avgUsmMintPrice)
            const targetTotalUsmSupply = totalUsmSupply0.add(targetUsmOut)
            shouldEqualApprox(user1UsmBalance, targetTotalUsmSupply)
            const totalUsmSupply = await usm.totalSupply()
            shouldEqualApprox(totalUsmSupply, targetTotalUsmSupply)
          })

          // ____________________ Burning FUM (aka defund()) ____________________

          it("allows burning FUM", async () => {
            const fumToBurn = user2FumBalance0.div(TEN) // defund 10% of the user's FUM
            await usm.defund(user2, user1, fumToBurn, 0, { from: user2 })
          })

          describe("with FUM burned at sliding price", () => {
            let fumToBurn, ethPoolD, priceD, debtRatioD, user2FumBalanceD, totalFumSupplyD, bidAskAdjD, fumBuyPriceD,
                fumSellPriceD, usmBuyPriceD, usmSellPriceD, targetEthPoolD, adjShrinkFactorD

            beforeEach(async () => {
              fumToBurn = user2FumBalance0.div(TEN)
              await usm.defund(user2, user1, fumToBurn, 0, { from: user2 })

              ethPoolD = await usm.ethPool()                    // "D" suffix = values after this defund() call
              priceD = (await usm.latestPrice())[0]
              debtRatioD = await usmView.debtRatio()
              user2FumBalanceD = await fum.balanceOf(user2)
              totalFumSupplyD = await fum.totalSupply()
              bidAskAdjD = await usm.bidAskAdjustment()
              fumBuyPriceD = await usmView.fumPrice(sides.BUY)
              fumSellPriceD = await usmView.fumPrice(sides.SELL)
              usmBuyPriceD = await usmView.usmPrice(sides.BUY)
              usmSellPriceD = await usmView.usmPrice(sides.SELL)

              // See USMTemplate.fumFromFund() for the math we're mirroring here:

              const adjustedEthUsdPrice0 = bidAskAdjustedEthUsdPrice(fl(price0), fl(bidAskAdj0), sides.SELL)
              const lowerBoundEthQty1 = fl(ethPool0) - fl(fumToBurn) * fl(fumSellPrice0)
              const lowerBoundEthShrinkFactor1 = lowerBoundEthQty1 / fl(ethPool0)
              const adjustedEthUsdPrice1 = adjustedEthUsdPrice0 * lowerBoundEthShrinkFactor1**4
              const debtRatio1 = fl(totalUsmSupply0) / (lowerBoundEthQty1 * adjustedEthUsdPrice1)
              const debtRatio2 = Math.min(debtRatio1, fl(MAX_DEBT_RATIO))
              const netFumDelta2 = 1 / (1 - debtRatio2) - 1
              adjShrinkFactorD = lowerBoundEthShrinkFactor1**(netFumDelta2 / 2)
            })

            it("reduces FUM supply correctly when burning FUM", async () => {
              const targetTotalFumSupplyD = totalFumSupply0.sub(fumToBurn)
              shouldEqual(user2FumBalanceD, targetTotalFumSupplyD)
              shouldEqual(totalFumSupplyD, targetTotalFumSupplyD)
            })

            it("reduces bidAskAdjustment correctly when burning FUM", async () => {
              bidAskAdjD.should.be.bignumber.lt(bidAskAdj0)
              const targetBidAskAdjD = wad(fl(bidAskAdj0) * adjShrinkFactorD)
              shouldEqualApprox(bidAskAdjD, targetBidAskAdjD)
            })

            it("reduces ETH mid price correctly when burning FUM", async () => {
              const targetPriceD = wad(fl(price0) * adjShrinkFactorD)
              shouldEqualApprox(priceD, targetPriceD)
            })

            it("reduces FUM buy and sell prices correctly when burning FUM", async () => {
              // As with minting USM (see check above), burning FUM has mixed effects on FUM price: no simple check to do here.

              checkFumBuyAndSellPrices(priceD, bidAskAdjD, ethPoolD, totalUsmSupply0, totalFumSupplyD, debtRatioD,
                                       fumBuyPriceD, fumSellPriceD)
            })

            it("increases USM buy and sell prices when burning FUM", async () => {
              // Burning FUM 1. reduces ETH mid price and 2. reduces bidAskAdj - both bad for USM buyers, good for USM sellers:
              usmBuyPriceD.should.be.bignumber.gt(usmBuyPrice0)
              usmSellPriceD.should.be.bignumber.gt(usmSellPrice0)

              checkUsmBuyAndSellPrices(priceD, bidAskAdjD, usmBuyPriceD, usmSellPriceD)
            })

            it("reduces ETH pool correctly when burning FUM", async () => {
              // Math from USMTemplate.ethFromDefund():
              const adjustedEthUsdPrice0 = bidAskAdjustedEthUsdPrice(fl(price0), fl(bidAskAdj0), sides.SELL)
              const adjustedEthUsdPrice2 = adjustedEthUsdPrice0 * adjShrinkFactorD**2
              const fumSellPrice2 = fumPrice(adjustedEthUsdPrice2, fl(ethPool0), fl(totalUsmSupply0), fl(totalFumSupply0))
              const avgFumSellPrice = (fl(fumSellPrice0) + fumSellPrice2) / 2
              const ethOut = fl(fumToBurn) * avgFumSellPrice
              const targetEthPoolD = wad(fl(ethPool0) - ethOut)
              shouldEqualApprox(ethPoolD, targetEthPoolD)
            })

            it("increases debtRatio when burning FUM", async () => {
              debtRatioD.should.be.bignumber.gt(debtRatio0)
            })
          })

          it("sending FUM to the FUM contract is a defund", async () => {
            const fumToBurn = user2FumBalance0.div(TEN) // defund 10% of the user's FUM
            await fum.transfer(fum.address, fumToBurn, { from: user2 })

            // These checks are crude simplifications of the "with FUM burned at sliding price" checks above:
            const user2FumBalance = await fum.balanceOf(user2)
            const targetTotalFumSupply = user2FumBalance0.sub(fumToBurn)
            shouldEqual(user2FumBalance, targetTotalFumSupply)
            const totalFumSupply = await fum.totalSupply()
            shouldEqual(totalFumSupply, targetTotalFumSupply)

            const bidAskAdj = await usm.bidAskAdjustment()
            bidAskAdj.should.be.bignumber.lt(bidAskAdj0)
            const price = (await usm.latestPrice())[0]
            price.should.be.bignumber.lt(price0)

            const ethPool = await usm.ethPool()
            ethPool.should.be.bignumber.lt(ethPool0)
          })

          it("sending FUM to the USM contract is a defund", async () => {
            const fumToBurn = user2FumBalance0.div(TEN) // defund 10% of the user's FUM
            await fum.transfer(usm.address, fumToBurn, { from: user2 })

            // These checks are crude simplifications of the "with FUM burned at sliding price" checks above:
            const user2FumBalance = await fum.balanceOf(user2)
            const targetTotalFumSupply = user2FumBalance0.sub(fumToBurn)
            shouldEqual(user2FumBalance, targetTotalFumSupply)
            const totalFumSupply = await fum.totalSupply()
            shouldEqual(totalFumSupply, targetTotalFumSupply)

            const bidAskAdj = await usm.bidAskAdjustment()
            bidAskAdj.should.be.bignumber.lt(bidAskAdj0)
            const price = (await usm.latestPrice())[0]
            price.should.be.bignumber.lt(price0)

            const ethPool = await usm.ethPool()
            ethPool.should.be.bignumber.lt(ethPool0)
          })

          it("users can opt out of receiving FUM", async () => {
            await expectRevert(fum.transfer(optOut1, 1, { from: user2 }), "Target opted out") // Set in constructor
            await expectRevert(fum.transfer(optOut2, 1, { from: user2 }), "Target opted out") // Set in constructor
            await fum.optOut({ from: user1 })
            await expectRevert(fum.transfer(user1, 1, { from: user2 }), "Target opted out")
          })

          it("users can opt back in to receiving FUM", async () => {
            await fum.optOut({ from: user1 })
            await fum.optBackIn({ from: user1 })
            await fum.transfer(user1, 1, { from: user2 })
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            // Move price to get debt ratio just *below* MAX.  Eg, if debt ratio is currently 156%, increasing the price by
            // (156% / 79%) should bring debt ratio to just about 79%:
            const targetDebtRatio1 = MAX_DEBT_RATIO.sub(WAD.div(HUNDRED)) // Eg, 80% - 1% = 79%
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1, false)
            const targetPrice1 = wadMul(price0, priceChangeFactor1, true)
            await oracle.setPrice(targetPrice1)
            await usm.refreshPrice()
            const price1 = (await usm.latestPrice())[0]
            shouldEqualApprox(price1, targetPrice1)

            const debtRatio1 = await usmView.debtRatio()
            debtRatio1.should.be.bignumber.lt(MAX_DEBT_RATIO)

            // Now this tiny defund() should succeed:
            await usm.defund(user2, user1, oneFum, 0, { from: user2 })

            const debtRatio2 = await usmView.debtRatio()
            // Next, similarly move price to get debt ratio just *above* MAX:
            const targetDebtRatio3 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3, true)
            const targetPrice3 = wadMul(price1, priceChangeFactor3, false)
            await oracle.setPrice(targetPrice3)
            await usm.refreshPrice()
            const price3 = (await usm.latestPrice())[0]
            shouldEqualApprox(price3, targetPrice3)

            const debtRatio3 = await usmView.debtRatio()
            debtRatio3.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // And now defund() should fail:
            await expectRevert(usm.defund(user2, user1, oneFum, 0, { from: user2 }), "Debt ratio > max")
          })

          // ____________________ Burning USM (aka burn()) ____________________

          it("allows burning USM", async () => {
            const usmToBurn = user1UsmBalance0.div(TEN) // defund 10% of the user's USM
            await usm.burn(user1, user2, usmToBurn, 0, { from: user1 })
          })

          describe("with USM burned at sliding price", () => {
            let usmToBurn, priceB, ethPoolB, debtRatioB, user1UsmBalanceB, totalUsmSupplyB, bidAskAdjB, fumBuyPriceB,
                fumSellPriceB, usmBuyPriceB, usmSellPriceB, adjGrowthFactorB

            beforeEach(async () => {
              usmToBurn = user1UsmBalance0.div(TEN) // Burning 100% of USM is an esoteric case - instead burn 10%
              //usmToBurn = oneUsm // defund 1 USM - tiny, so that the burn itself moves price more than the collected fees do
              await usm.burn(user1, user2, usmToBurn, 0, { from: user1 })

              ethPoolB = await usm.ethPool()                    // "B" suffix = values after this burn() call
              priceB = (await usm.latestPrice())[0]
              debtRatioB = await usmView.debtRatio()
              user1UsmBalanceB = await usm.balanceOf(user1)
              totalUsmSupplyB = await usm.totalSupply()
              bidAskAdjB = await usm.bidAskAdjustment()
              fumBuyPriceB = await usmView.fumPrice(sides.BUY)
              fumSellPriceB = await usmView.fumPrice(sides.SELL)
              usmBuyPriceB = await usmView.usmPrice(sides.BUY)
              usmSellPriceB = await usmView.usmPrice(sides.SELL)

              adjGrowthFactorB = Math.exp(fl(usmToBurn) * fl(usmSellPrice0) / (2 * fl(ethPool0)))
            })

            it("reduces USM supply correctly when burning USM", async () => {
              const targetTotalUsmSupplyB = totalUsmSupply0.sub(usmToBurn)
              shouldEqual(user1UsmBalanceB, targetTotalUsmSupplyB)
              shouldEqual(totalUsmSupplyB, targetTotalUsmSupplyB)
            })

            it("increases bidAskAdjustment correctly when burning USM", async () => {
              bidAskAdjB.should.be.bignumber.gt(bidAskAdj0)
              const targetBidAskAdjB = wad(fl(bidAskAdj0) * adjGrowthFactorB)
              shouldEqualApprox(bidAskAdjB, targetBidAskAdjB)
            })

            it("increases ETH mid price correctly when burning USM", async () => {
              const targetPriceB = wad(fl(price0) * adjGrowthFactorB)
              shouldEqualApprox(priceB, targetPriceB)
            })

            it("reduces USM buy and sell prices correctly when burning USM", async () => {
              // Burning USM 1. increases ETH mid price and 2. increases bidAskAdj - good for USM buyers, bad for USM sellers:
              usmBuyPriceB.should.be.bignumber.lt(usmBuyPrice0)
              usmSellPriceB.should.be.bignumber.lt(usmSellPrice0)

              checkUsmBuyAndSellPrices(priceB, bidAskAdjB, usmBuyPriceB, usmSellPriceB)
            })

            it("increases FUM buy and sell prices when burning USM", async () => {
              // Burning USM 1. pushes ETH mid price up 2. pushes bidAskAdj up and 3. collects fees for FUM holders.  All three
              // of these are bad for FUM buyers/minters (fumBuyPrice up), and good for FUM sellers/burners (fumSellPrice up):
              fumBuyPriceB.should.be.bignumber.gt(fumBuyPrice0)
              fumSellPriceB.should.be.bignumber.gte(fumSellPrice0)  // gte b/c fumSellPrice is floored at 0, so both might be 0

              checkFumBuyAndSellPrices(priceB, bidAskAdjB, ethPoolB, totalUsmSupplyB, totalFumSupply0, debtRatioB,
                                       fumBuyPriceB, fumSellPriceB)
            })

            it("reduces ETH pool correctly when burning USM", async () => {
              // Math from USMTemplate.ethFromBurn():
              const targetEthPoolB = wad(fl(ethPool0) / adjGrowthFactorB**2)
              shouldEqualApprox(ethPoolB, targetEthPoolB)
            })

            it("reduces debtRatio when burning USM", async () => {
              debtRatioB.should.be.bignumber.lt(debtRatio0)
            })
          })

          it("sending USM to the USM contract burns it", async () => {
            const usmToBurn = user1UsmBalance0.div(TEN) // defund 10% of the user's USM
            await usm.transfer(usm.address, usmToBurn, { from: user1 })

            // These checks are all cribbed from the "with USM burned at sliding price" checks above:
            const user1UsmBalance = await usm.balanceOf(user1)
            const targetTotalUsmSupply = user1UsmBalance0.sub(usmToBurn)
            shouldEqual(user1UsmBalance, targetTotalUsmSupply)
            const totalUsmSupply = await usm.totalSupply()
            shouldEqual(totalUsmSupply, targetTotalUsmSupply)

            const ethPool = await usm.ethPool()
            const targetEthPool = wad(fl(ethPool0) / Math.exp(fl(usmToBurn) * fl(usmSellPrice0) / fl(ethPool0)))
            shouldEqualApprox(ethPool, targetEthPool)

            const bidAskAdj = await usm.bidAskAdjustment()
            const adjGrowthFactor = (fl(ethPool0) / fl(ethPool))**0.5
            const targetBidAskAdj = wad(fl(bidAskAdj0) * adjGrowthFactor)
            shouldEqualApprox(bidAskAdj, targetBidAskAdj)
            const price = (await usm.latestPrice())[0]
            const targetPrice = wad(fl(price0) * adjGrowthFactor)
            shouldEqualApprox(price, targetPrice)
          })

          it("sending USM to the FUM contract burns it", async () => {
            const usmToBurn = user1UsmBalance0.div(TEN) // defund 10% of the user's USM
            await usm.transfer(fum.address, usmToBurn, { from: user1 })

            // These checks are all cribbed from the "with USM burned at sliding price" checks above:
            const user1UsmBalance = await usm.balanceOf(user1)
            const targetTotalUsmSupply = user1UsmBalance0.sub(usmToBurn)
            shouldEqual(user1UsmBalance, targetTotalUsmSupply)
            const totalUsmSupply = await usm.totalSupply()
            shouldEqual(totalUsmSupply, targetTotalUsmSupply)

            const ethPool = await usm.ethPool()
            const targetEthPool = wad(fl(ethPool0) / Math.exp(fl(usmToBurn) * fl(usmSellPrice0) / fl(ethPool0)))
            shouldEqualApprox(ethPool, targetEthPool)

            const bidAskAdj = await usm.bidAskAdjustment()
            const adjGrowthFactor = (fl(ethPool0) / fl(ethPool))**0.5
            const targetBidAskAdj = wad(fl(bidAskAdj0) * adjGrowthFactor)
            shouldEqualApprox(bidAskAdj, targetBidAskAdj)
            const price = (await usm.latestPrice())[0]
            const targetPrice = wad(fl(price0) * adjGrowthFactor)
            shouldEqualApprox(price, targetPrice)
          })

          it("users can opt out of receiving USM", async () => {
            await expectRevert(usm.transfer(optOut1, 1, { from: user1 }), "Target opted out") // Set in constructor
            await expectRevert(usm.transfer(optOut2, 1, { from: user1 }), "Target opted out") // Set in constructor
            await usm.optOut({ from: user2 })
            await expectRevert(usm.transfer(user2, user1UsmBalance0, { from: user1 }), "Target opted out")
          })

          it("users can opt back in to receiving USM", async () => {
            await usm.optOut({ from: user2 })
            await usm.optBackIn({ from: user2 })
            await usm.transfer(user2, user1UsmBalance0, { from: user1 })
          })

          it("allows burning USM if debt ratio over 100%", async () => {
            // Move price to get debt ratio just *below* 100%:
            const targetDebtRatio1 = WAD.mul(HUNDRED.sub(ONE)).div(HUNDRED) // 99%
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1, false)
            const targetPrice1 = wadMul(price0, priceChangeFactor1, true)
            await oracle.setPrice(targetPrice1)
            await usm.refreshPrice()
            const price1 = (await usm.latestPrice())[0]
            shouldEqualApprox(price1, targetPrice1)

            const debtRatio1 = await usmView.debtRatio()
            debtRatio1.should.be.bignumber.lt(WAD)

            // Now this tiny burn() should succeed:
            await usm.burn(user1, user2, oneUsm, 0, { from: user1 })

            // Move forward a day, so our bidAskAdj reverts to 1 (ie no adjustment):
            const block0 = await web3.eth.getBlockNumber()
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 1 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = await web3.eth.getBlockNumber()
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            shouldEqual(t1, t0 + timeDelay)

            // Next, similarly move price to get debt ratio just *above* 100%:
            const debtRatio2 = await usmView.debtRatio()
            const targetDebtRatio3 = WAD.mul(HUNDRED.add(ONE)).div(HUNDRED) // 101%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3, true)
            const targetPrice3 = wadMul(price1, priceChangeFactor3, false)
            await oracle.setPrice(targetPrice3)
            await usm.refreshPrice()
            const price3 = (await usm.latestPrice())[0]
            shouldEqualApprox(price3, targetPrice3)

            const debtRatio3 = await usmView.debtRatio()
            debtRatio3.should.be.bignumber.gt(WAD)

            // And now the same burn() should still succeed:
            await usm.burn(user1, user2, oneUsm, 0, { from: user1 })
          })
        })
      })
    })
  })
})
