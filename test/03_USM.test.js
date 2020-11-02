const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const timeMachine = require('ganache-time-traveler')

const Aggregator = artifacts.require('MockChainlinkAggregatorV3')
//const ChainlinkOracle = artifacts.require('ChainlinkOracle')
const UniswapAnchoredView = artifacts.require('MockUniswapAnchoredView')
//const CompoundOracle = artifacts.require('CompoundOpenOracle')
const UniswapV2Pair = artifacts.require('MockUniswapV2Pair')
//const UniswapOracle = artifacts.require('OurUniswapV2SpotOracle')
//const CompositeOracle = artifacts.require('MockCompositeOracle')
//const SettableOracle = artifacts.require('SettableOracle')

const WETH9 = artifacts.require('WETH9')
const WadMath = artifacts.require('MockWadMath')
const USM = artifacts.require('MockUSM')
const FUM = artifacts.require('FUM')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  const [ZERO, ONE, TWO, THREE, FOUR, EIGHT, TEN, HUNDRED, THOUSAND, WAD] =
        [0, 1, 2, 3, 4, 8, 10, 100, 1000, '1000000000000000000'].map(function (n) { return new BN(n) })
  const sides = { BUY: 0, SELL: 1 }
  const oneEth = WAD
  const oneUsm = WAD
  const oneFum = WAD
  const MINUTE = 60
  const HOUR = 60 * MINUTE
  const DAY = 24 * HOUR
  const tolerance = new BN('1000000000000')

  let priceWAD
  let oneDollarInEth
  const shift = '18'

  let aggregator
  const chainlinkPrice = '38598000000'
  const chainlinkShift = '8'

  let anchoredView
  const compoundPrice = '414174999'
  const compoundShift = '6'

  let pair
  const uniswapReserve0 = '646310144553926227215994'
  const uniswapReserve1 = '254384028636585'
  const uniswapReverseOrder = false
  const uniswapShift = '18'
  const uniswapScalePriceBy = (new BN(10)).pow(new BN(30))
  const uniswapPrice = '393594361437970499059' // = uniswapReserve1 * uniswapScalePriceBy / uniswapReserve0

  function wadMul(x, y) {
    return ((x.mul(y)).add(WAD.div(TWO))).div(WAD)
  }

  function wadSquared(x) {
    return wadMul(x, x)
  }

  function wadDiv(x, y) {
    return ((x.mul(WAD)).add(y.div(TWO))).div(y)
  }

  function wadSqrt(y) {
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

  function wadDecay(adjustment, decayFactor) {
    return WAD.add(wadMul(adjustment, decayFactor)).sub(decayFactor)
  }

  function shouldEqual(x, y) {
    x.toString().should.equal(y.toString())
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = (x.gt(y) ? x.sub(y) : y.sub(x))
    diff.should.be.bignumber.lt(x.add(y).div(new BN(1000000)))
  }

  function fl(w) { // Converts a WAD fixed-point (eg, 2.7e18) to an unscaled float (2.7).  Of course may lose a bit of precision
    return parseFloat(w) / 10**18
  }

  /* ____________________ Deployment ____________________ */

  describe("mints and burns a static amount", () => {
    let weth, usm, ethPerFund, ethPerMint, bitOfEth, snapshot, snapshotId

    beforeEach(async () => {
      // Oracle
      aggregator = await Aggregator.new({ from: deployer })
      await aggregator.set(chainlinkPrice);
  
      anchoredView = await UniswapAnchoredView.new({ from: deployer })
      await anchoredView.set(compoundPrice);
  
      pairA = await UniswapV2Pair.new({ from: deployer })
      await pairA.set(uniswapReserve0, uniswapReserve1);

      pairB = await UniswapV2Pair.new({ from: deployer })
      await pairB.set(uniswapReserve0, uniswapReserve1);

      pairC = await UniswapV2Pair.new({ from: deployer })
      await pairC.set(uniswapReserve0, uniswapReserve1);

      // USM
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(weth.address, aggregator.address, anchoredView.address,
                          pairA.address, true, pairB.address, false, pairC.address, true, { from: deployer })
      fum = await FUM.at(await usm.fum())

      priceWAD = await usm.oraclePrice()
      oneDollarInEth = wadDiv(WAD, priceWAD)

      ethPerFund = oneEth.mul(TWO)                  // Can be any (?) number
      const totalEthToFund = ethPerFund.mul(THREE)  // Based on three cumulative calls to fund() in tests below
      await weth.deposit({ from: user1, value: totalEthToFund })
      await weth.approve(usm.address, totalEthToFund, { from: user1 }) // user1 will spend ETH to fund FUM for user2

      ethPerMint = oneEth.mul(FOUR)                 // Can be any (?) number
      const totalEthToMint = ethPerMint.mul(TWO)    // Based on two cumulative calls to mint() in tests below
      await weth.deposit({ from: user2, value: totalEthToMint })
      await weth.approve(usm.address, totalEthToMint, { from: user2 }) // user2 will spend ETH to mint USM for user1

      bitOfEth = oneEth.div(THOUSAND)
      await weth.deposit({ from: user3, value: bitOfEth })
      await weth.approve(usm.address, bitOfEth, { from: user3 })

      snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']

    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe("deployment", () => {
      it("starts with correct FUM price", async () => {
        const fumBuyPrice = await usm.fumPrice(sides.BUY)
        // The FUM price should start off equal to $1, in ETH terms = 1 / price:
        shouldEqual(fumBuyPrice, oneDollarInEth)
        
        const fumSellPrice = await usm.fumPrice(sides.SELL)
        shouldEqual(fumSellPrice, oneDollarInEth)
      })
    })

    /* ____________________ Minting and burning ____________________ */

    describe("minting and burning", () => {
      let MAX_DEBT_RATIO, price0

      beforeEach(async () => {
        MAX_DEBT_RATIO = await usm.MAX_DEBT_RATIO()
        price0 = await usm.oraclePrice()
      })

      it("doesn't allow minting USM before minting FUM", async () => {
        await expectRevert(usm.mint(user2, user1, ethPerMint, { from: user2 }), "Fund before minting")
      })

      /* ____________________ Minting FUM (aka fund()) ____________________ */

      it("allows minting FUM", async () => {
        await usm.fund(user1, user2, ethPerFund, { from: user1 }) // fund() call #1
        await usm.fund(user1, user2, ethPerFund, { from: user1 }) // fund() call #2 (just to make sure #1 wasn't special)
      })

      describe("with existing FUM supply", () => {
        let ethPool1, user2FumBalance1, totalFumSupply1, buySellAdj1, fumBuyPrice1, fumSellPrice1

        beforeEach(async () => {
          await usm.fund(user1, user2, ethPerFund, { from: user1 })
          await usm.fund(user1, user2, ethPerFund, { from: user1 }) // Again two calls, just to check the 1st wasn't special

          ethPool1 = await usm.ethPool()
          user2FumBalance1 = await fum.balanceOf(user2)
          totalFumSupply1 = await fum.totalSupply()
          buySellAdj1 = await usm.buySellAdjustment()
          fumBuyPrice1 = await usm.fumPrice(sides.BUY)
          fumSellPrice1 = await usm.fumPrice(sides.SELL)
        })

        it("reverts FUM transfers to the USM contract", async () => {
          await expectRevert(
            fum.transfer(usm.address, 1),
            "Don't transfer here"
          )
        })

        it("reverts FUM transfers to the FUM contract", async () => {
          await expectRevert(
            fum.transfer(fum.address, 1),
            "Don't transfer here"
          )
        })

        it("uses flat FUM price until USM is minted", async () => {
          const targetEthPool1 = ethPerFund.mul(TWO)
          shouldEqual(ethPool1, targetEthPool1)

          // Check that the FUM created was just based on straight linear pricing - qty * price:
          const targetFumBalance1 = wadMul(ethPool1, priceWAD)
          shouldEqualApprox(user2FumBalance1, targetFumBalance1)    // Only approx b/c fumFromFund() loses some precision
          shouldEqualApprox(totalFumSupply1, targetFumBalance1)

          // And relatedly, buySellAdjustment should be unchanged (1), and FUM buy price and FUM sell price should still be $1:
          shouldEqual(buySellAdj1, WAD)
          shouldEqual(fumBuyPrice1, oneDollarInEth)
          shouldEqual(fumSellPrice1, oneDollarInEth)
        })

        /* ____________________ Minting USM (aka mint()) ____________________ */

        it("allows minting USM", async () => {
          await usm.mint(user2, user1, ethPerMint, { from: user2 })
        })

        describe("with existing USM supply", () => {
          let ethPool2, debtRatio2, user1UsmBalance2, totalUsmSupply2, buySellAdj2, fumBuyPrice2, fumSellPrice2, usmBuyPrice2,
              usmSellPrice2

          beforeEach(async () => {
            await usm.mint(user2, user1, ethPerMint, { from: user2 })

            ethPool2 = await usm.ethPool()
            debtRatio2 = await usm.debtRatio()
            user1UsmBalance2 = await usm.balanceOf(user1)
            totalUsmSupply2 = await usm.totalSupply()
            buySellAdj2 = await usm.buySellAdjustment()
            fumBuyPrice2 = await usm.fumPrice(sides.BUY)
            fumSellPrice2 = await usm.fumPrice(sides.SELL)
            usmBuyPrice2 = await usm.usmPrice(sides.BUY)
            usmSellPrice2 = await usm.usmPrice(sides.SELL)
          })

          it("reverts USM transfers to the USM contract", async () => {
            await expectRevert(
              usm.transfer(usm.address, 1),
              "Don't transfer here"
            )
          })
  
          it("reverts USM transfers to the FUM contract", async () => {
            await expectRevert(
              usm.transfer(fum.address, 1),
              "Don't transfer here"
            )
          })

          it("uses flat USM price first time USM is minted", async () => {
            const targetEthPool2 = ethPool1.add(ethPerMint)
            shouldEqual(ethPool2, targetEthPool2)

            // The first mint() call doesn't use sliding prices, or update buySellAdjustment, because before this call the debt
            // ratio is 0.  Only once debt ratio becomes non-zero after this call does the system start applying sliding prices.
            const targetUsmBalance2 = wadMul(ethPerMint, priceWAD)
            shouldEqualApprox(user1UsmBalance2, targetUsmBalance2)  // Only approx b/c usmFromMint() loses some precision
            shouldEqualApprox(totalUsmSupply2, targetUsmBalance2)

            shouldEqual(buySellAdj2, WAD)
            shouldEqual(fumBuyPrice2, oneDollarInEth)
            shouldEqual(fumSellPrice2, oneDollarInEth)
          })

          it("reduces minFumBuyPrice over time", async () => {
            // Move price to get debt ratio just *above* MAX:
            const targetDebtRatio3 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3)
            const targetPrice3 = wadMul(price0, priceChangeFactor3)
            await usm.setPrice(targetPrice3)
            const price3 = await usm.oraclePrice()
            shouldEqual(price3, targetPrice3)

            const debtRatio3 = await usm.debtRatio()
            debtRatio3.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // Calculate targetMinFumBuyPrice using the math in USM._updateMinFumBuyPrice():
            const fumSupply = await fum.totalSupply()
            const targetMinFumBuyPrice4 = wadDiv(wadMul(WAD.sub(MAX_DEBT_RATIO), ethPool2), fumSupply)

            // Make one tiny call to fund(), just to actually trigger the internal call to _updateMinFumBuyPrice():
            await usm.fund(user3, user3, bitOfEth, { from: user3 })

            const minFumBuyPrice4 = await usm.minFumBuyPrice()
            shouldEqual(minFumBuyPrice4, targetMinFumBuyPrice4)

            // Now move forward a few days, and check that minFumBuyPrice decays by the appropriate factor:
            const block0 = await web3.eth.getBlockNumber()
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 3 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = await web3.eth.getBlockNumber()
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            shouldEqual(t1, t0 + timeDelay)

            const minFumBuyPrice5 = await usm.minFumBuyPrice()
            const decayFactor5 = wadDiv(ONE, EIGHT)
            const targetMinFumBuyPrice5 = wadMul(minFumBuyPrice4, decayFactor5)
            shouldEqual(minFumBuyPrice5, targetMinFumBuyPrice5)
          })

          /* ____________________ Minting FUM (aka fund()), now at sliding price ____________________ */

          describe("with FUM minted at sliding price", () => {
            let ethPool3, debtRatio3, user2FumBalance3, totalFumSupply3, buySellAdj3, fumBuyPrice3, fumSellPrice3, usmBuyPrice3,
                usmSellPrice3

            beforeEach(async () => {
              await usm.fund(user1, user2, ethPerFund, { from: user1 })

              ethPool3 = await usm.ethPool()
              debtRatio3 = await usm.debtRatio()
              user2FumBalance3 = await fum.balanceOf(user2)
              totalFumSupply3 = await fum.totalSupply()
              buySellAdj3 = await usm.buySellAdjustment()
              fumBuyPrice3 = await usm.fumPrice(sides.BUY)
              fumSellPrice3 = await usm.fumPrice(sides.SELL)
              usmBuyPrice3 = await usm.usmPrice(sides.BUY)
              usmSellPrice3 = await usm.usmPrice(sides.SELL)
            })

            it("calculates sqrt correctly", async () => {
              const roots = [1, 2, 3, 7, 10, 99, 1001, 10000, 99999, 1000001]
              const w = await WadMath.new()
              let i, r, square, sqrt
              for (i = 0; i < roots.length; ++i) {
                r = (new BN(roots[i])).mul(WAD)
                square = wadSquared(r)
                sqrt = await w.wadSqrt(square)
                shouldEqual(sqrt, r)            // wadSqrt(49000000000000000000) should return 7000000000000000000
                sqrt = await w.wadSqrt(square.add(ONE))
                shouldEqual(sqrt, r)            // wadSqrt(49000000000000000001) should return 7000000000000000000 too
                sqrt = await w.wadSqrt(square.sub(ONE))
                shouldEqual(sqrt, r.sub(ONE))   // wadSqrt(48999999999999999999) should return 6999999999999999999 (ie, round down)
              }
            })

            it("slides price correctly when minting FUM", async () => {
              const targetEthPool3 = ethPool2.add(ethPerFund)
              shouldEqual(ethPool3, targetEthPool3)

              // Check vs the integral math in USM.fumFromFund():
              const integralFirstPart = wadMul(debtRatio2, wadSquared(ethPool3).sub(wadSquared(ethPool2)))
              const targetFumBalance3 = wadDiv(wadSqrt(integralFirstPart.add(wadSquared(wadMul(totalFumSupply1, fumBuyPrice2)))),
                                               fumBuyPrice2)
              shouldEqual(user2FumBalance3, targetFumBalance3)
              shouldEqual(totalFumSupply3, targetFumBalance3)
            })

            it("reduces debtRatio when minting FUM", async () => {
              debtRatio3.should.be.bignumber.lt(debtRatio2)
            })

            it("increases buySellAdjustment when minting FUM", async () => {
              buySellAdj3.should.be.bignumber.gt(buySellAdj2)
              // Or maybe calculate that the reduction is exactly what it should be...
            })

            it("modifies FUM mint/USM burn prices as a result of minting FUM", async () => {
              // The fund() call, being a "long-ETH" operation, will make both types of long-ETH operations - fund()s and
              // burn()s - more expensive (ie, at worse prices): fund()'s fumBuyPrice should have increased (user pays a higher
              // price for further FUM), and burn()'s usmSellPrice should have decreased (user gets a lower price for their USM):
              fumBuyPrice3.should.be.bignumber.gt(fumBuyPrice2)
              usmSellPrice3.should.be.bignumber.lt(usmSellPrice2)

              // Meanwhile the USM *buy* price should be unchanged.  The FUM sell price will be (at least slightly) increased due
              // to fees the system collected from the fund() op above:
              shouldEqual(usmBuyPrice3, usmBuyPrice2)
              fumSellPrice3.should.be.bignumber.gt(fumSellPrice2)
            })

            it("decays buySellAdjustment over time", async () => {
              // Check that buySellAdjustment decays properly (well, approximately) over time:
              // - Start with an adjustment j != 1.
              // - Use timeMachine to move forward 180 secs = 3 min.
              // - Since USM.BUY_SELL_ADJUSTMENT_HALF_LIFE = 60 (1 min), 3 min should mean a decay of ~1/8.
              // - The way our "time decay towards 1" approximation works, decaying j by ~1/8 should yield 1 + (j * 1/8) - 1/8.
              //   (See comment in USM.buySellAdjustment().)

              // Need buySellAdj to be active (ie, != 1) for this test to be meaningful.  After fund() above it should be > 1:
              buySellAdj3.should.be.bignumber.gt(buySellAdj2)

              const block0 = await web3.eth.getBlockNumber()
              const t0 = (await web3.eth.getBlock(block0)).timestamp
              const timeDelay = 3 * MINUTE
              await timeMachine.advanceTimeAndBlock(timeDelay)
              const block1 = await web3.eth.getBlockNumber()
              const t1 = (await web3.eth.getBlock(block1)).timestamp
              shouldEqual(t1, t0 + timeDelay)

              const buySellAdj4 = await usm.buySellAdjustment()
              const decayFactor4 = wadDiv(ONE, EIGHT)
              const targetBuySellAdj4 = wadDecay(buySellAdj3, decayFactor4)
              shouldEqual(buySellAdj4, targetBuySellAdj4)
            })
          })

          it("allows minting USM with sliding price", async () => {
            // Now for the second mint() call, which *should* create USM at a sliding price, since debt ratio is no longer 0:
            await usm.mint(user2, user1, ethPerMint, { from: user2 })
          })

          /* ____________________ Minting USM (aka mint()), now at sliding price ____________________ */

          describe("with USM minted at sliding price", () => {
            let ethPool3, debtRatio3, user1UsmBalance3, totalUsmSupply3, buySellAdj3, fumBuyPrice3, fumSellPrice3, usmBuyPrice3,
                usmSellPrice3

            beforeEach(async () => {
              await usm.mint(user2, user1, ethPerMint, { from: user2 })

              ethPool3 = await usm.ethPool()
              debtRatio3 = await usm.debtRatio()
              user1UsmBalance3 = await usm.balanceOf(user1)
              totalUsmSupply3 = await usm.totalSupply()
              buySellAdj3 = await usm.buySellAdjustment()
              fumBuyPrice3 = await usm.fumPrice(sides.BUY)
              fumSellPrice3 = await usm.fumPrice(sides.SELL)
              usmBuyPrice3 = await usm.usmPrice(sides.BUY)
              usmSellPrice3 = await usm.usmPrice(sides.SELL)
            })

            it("slides price correctly when minting USM", async () => {
              const targetEthPool3 = ethPool2.add(ethPerMint)
              shouldEqual(ethPool3, targetEthPool3)

              // Check vs the integral math in USM.usmFromMint():
              const integralFirstPart = wadMul(debtRatio2, wadSquared(ethPool3).sub(wadSquared(ethPool2)))
              const targetUsmBalance3 = wadDiv(wadSqrt(integralFirstPart.add(wadSquared(wadMul(totalUsmSupply2, usmBuyPrice2)))),
                                               usmBuyPrice2)
              shouldEqual(user1UsmBalance3, targetUsmBalance3)
              shouldEqual(totalUsmSupply3, targetUsmBalance3)
            })

            it("moves debtRatio towards 100% when minting USM", async () => {
              if (debtRatio2.lt(WAD)) {
                debtRatio3.should.be.bignumber.gt(debtRatio2)
              } else {
                debtRatio3.should.be.bignumber.lt(debtRatio2)
              }
            })

            it("reduces buySellAdjustment when minting USM", async () => {
              buySellAdj3.should.be.bignumber.lt(buySellAdj2)
            })

            it("modifies USM mint/FUM burn prices as a result of minting USM", async () => {
              // See parallel check after minting FUM above.
              usmBuyPrice3.should.be.bignumber.gt(usmBuyPrice2)
              fumSellPrice3.should.be.bignumber.lt(fumSellPrice2)
              shouldEqual(usmSellPrice3, usmSellPrice2)
              fumBuyPrice3.should.be.bignumber.gt(fumBuyPrice2)
            })
          })

          /* ____________________ Burning FUM (aka defund()) ____________________ */

          it("allows burning FUM", async () => {
            const fumToBurn = user2FumBalance1.div(TWO) // defund 50% of the user's FUM
            await usm.defund(user2, user1, fumToBurn, { from: user2 })
          })

          describe("with FUM burned at sliding price", () => {
            let fumToBurn, ethPool3, debtRatio3, user2FumBalance3, totalFumSupply3, buySellAdj3, fumBuyPrice3, fumSellPrice3,
                usmBuyPrice3, usmSellPrice3

            beforeEach(async () => {
              fumToBurn = user2FumBalance1.div(TWO)
              await usm.defund(user2, user1, fumToBurn, { from: user2 })

              ethPool3 = await usm.ethPool()
              debtRatio3 = await usm.debtRatio()
              user2FumBalance3 = await fum.balanceOf(user2)
              totalFumSupply3 = await fum.totalSupply()
              buySellAdj3 = await usm.buySellAdjustment()
              fumBuyPrice3 = await usm.fumPrice(sides.BUY)
              fumSellPrice3 = await usm.fumPrice(sides.SELL)
              usmBuyPrice3 = await usm.usmPrice(sides.BUY)
              usmSellPrice3 = await usm.usmPrice(sides.SELL)
            })

            it("slides price correctly when burning FUM", async () => {
              const targetFumBalance3 = user2FumBalance1.sub(fumToBurn)
              shouldEqual(user2FumBalance3, targetFumBalance3)
              shouldEqual(totalFumSupply3, targetFumBalance3)

              // Check vs the integral math in USM.ethFromDefund():
              const integralFirstPart = wadMul(wadSquared(totalFumSupply1).sub(wadSquared(totalFumSupply3)),
                                               wadSquared(fumSellPrice2))
              const targetEthPool3 = wadSqrt(wadSquared(ethPool2).sub(wadDiv(integralFirstPart, debtRatio2)))
              shouldEqual(ethPool3, targetEthPool3)
            })

            it("increases debtRatio when burning FUM", async () => {
              debtRatio3.should.be.bignumber.gt(debtRatio2)
            })

            it("reduces buySellAdjustment when burning FUM", async () => {
              buySellAdj3.should.be.bignumber.lt(buySellAdj2)
            })

            it("modifies FUM burn/USM mint prices as a result of burning FUM", async () => {
              // See parallel check after minting FUM above.
              fumSellPrice3.should.be.bignumber.lt(fumSellPrice2)
              usmBuyPrice3.should.be.bignumber.gt(usmBuyPrice2)
              fumBuyPrice3.should.be.bignumber.gt(fumBuyPrice2)
              shouldEqual(usmSellPrice3, usmSellPrice2)
            })
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            // Move price to get debt ratio just *below* MAX.  Eg, if debt ratio is currently 156%, increasing the price by
            // (156% / 79%%) should bring debt ratio to just about 79%:
            const targetDebtRatio3 = MAX_DEBT_RATIO.sub(WAD.div(HUNDRED)) // Eg, 80% - 1% = 79%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3)
            const targetPrice3 = wadMul(price0, priceChangeFactor3)
            await usm.setPrice(targetPrice3)
            const price3 = await usm.oraclePrice()
            shouldEqual(price3, targetPrice3)

            const debtRatio3 = await usm.debtRatio()
            debtRatio3.should.be.bignumber.lt(MAX_DEBT_RATIO)

            // Now this tiny defund() should succeed:
            await usm.defund(user2, user1, oneFum, { from: user2 })

            const debtRatio4 = await usm.debtRatio()
            // Next, similarly move price to get debt ratio just *above* MAX:
            const targetDebtRatio5 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const priceChangeFactor5 = wadDiv(debtRatio4, targetDebtRatio5)
            const targetPrice5 = wadMul(price3, priceChangeFactor5)
            await usm.setPrice(targetPrice5)
            const price5 = await usm.oraclePrice()
            shouldEqual(price5, targetPrice5)

            const debtRatio5 = await usm.debtRatio()
            debtRatio5.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // And now defund() should fail:
            await expectRevert(usm.defund(user2, user1, oneFum, { from: user2 }), "Max debt ratio breach")
          })

          /* ____________________ Burning USM (aka burn()) ____________________ */

          it("allows burning USM", async () => {
            const usmToBurn = user1UsmBalance2.div(TWO) // defund 50% of the user's USM
            await usm.burn(user1, user2, usmToBurn, { from: user1 })
          })

          describe("with USM burned at sliding price", () => {
            let usmToBurn, ethPool3, debtRatio3, user1UsmBalance3, totalUsmSupply3, buySellAdj3, fumBuyPrice3, fumSellPrice3,
                usmBuyPrice3, usmSellPrice3

            beforeEach(async () => {
              usmToBurn = user1UsmBalance2.div(TWO) // Burning 100% of USM is an esoteric case - instead burn 50%
              await usm.burn(user1, user2, usmToBurn, { from: user1 })

              ethPool3 = await usm.ethPool()
              debtRatio3 = await usm.debtRatio()
              user1UsmBalance3 = await usm.balanceOf(user1)
              totalUsmSupply3 = await usm.totalSupply()
              buySellAdj3 = await usm.buySellAdjustment()
              fumBuyPrice3 = await usm.fumPrice(sides.BUY)
              fumSellPrice3 = await usm.fumPrice(sides.SELL)
              usmBuyPrice3 = await usm.usmPrice(sides.BUY)
              usmSellPrice3 = await usm.usmPrice(sides.SELL)
            })

            it("slides price correctly when burning USM", async () => {
              //console.log("user1 USM: " + fl(user1UsmBalance2) + ", " + fl(user1UsmBalance3) + ", " + fl(usmToBurn))
              const targetUsmBalance3 = user1UsmBalance2.sub(usmToBurn)
              shouldEqual(user1UsmBalance3, targetUsmBalance3)
              shouldEqual(totalUsmSupply3, targetUsmBalance3)

              // Check vs the integral math in USM.ethFromBurn():
              const integralFirstPart = wadMul(wadSquared(totalUsmSupply2).sub(wadSquared(totalUsmSupply3)),
                                               wadSquared(usmSellPrice2))
              const targetEthPool3 = wadSqrt(wadSquared(ethPool2).sub(wadDiv(integralFirstPart, debtRatio2)))
              shouldEqual(ethPool3, targetEthPool3)
            })

            it("decreases debtRatio when burning USM", async () => {
              debtRatio3.should.be.bignumber.lt(debtRatio2)
            })

            it("increases buySellAdjustment when burning USM", async () => {
              buySellAdj3.should.be.bignumber.gt(buySellAdj2)
            })

            it("modifies USM burn/FUM mint prices as a result of burning USM", async () => {
              // See parallel check after minting FUM above.
              usmSellPrice3.should.be.bignumber.lt(usmSellPrice2)
              fumBuyPrice3.should.be.bignumber.gt(fumBuyPrice2)
              shouldEqual(usmBuyPrice3, usmBuyPrice2)
              fumSellPrice3.should.be.bignumber.gt(fumSellPrice2)
            })
          })

          it("doesn't allow burning USM if debt ratio over 100%", async () => {
            // Move price to get debt ratio just *below* 100%:
            const targetDebtRatio3 = WAD.mul(HUNDRED.sub(ONE)).div(HUNDRED) // 99%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3)
            const targetPrice3 = wadMul(price0, priceChangeFactor3)
            await usm.setPrice(targetPrice3)
            const price3 = await usm.oraclePrice()
            shouldEqual(price3, targetPrice3)

            const debtRatio3 = await usm.debtRatio()
            debtRatio3.should.be.bignumber.lt(WAD)

            // Now this tiny burn() should succeed:
            await usm.burn(user1, user2, oneUsm, { from: user1 })

            // Next, similarly move price to get debt ratio just *above* 100%:
            const debtRatio4 = await usm.debtRatio()
            const targetDebtRatio5 = WAD.mul(HUNDRED.add(ONE)).div(HUNDRED) // 101%
            const priceChangeFactor5 = wadDiv(debtRatio4, targetDebtRatio5)
            const targetPrice5 = wadMul(price3, priceChangeFactor5)
            await usm.setPrice(targetPrice5)
            const price5 = await usm.oraclePrice()
            shouldEqual(price5, targetPrice5)

            const debtRatio5 = await usm.debtRatio()
            debtRatio5.should.be.bignumber.gt(WAD)

            // And now the same burn() should fail:
            await expectRevert(usm.burn(user1, user2, oneUsm, { from: user1 }), "Debt ratio too high")
          })
        })
      })
    })
  })
})
