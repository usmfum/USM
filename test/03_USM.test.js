const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const timeMachine = require('ganache-time-traveler')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  function wadMul(x, y) {
    return x.mul(y).div(WAD);
  }

  function wadDiv(x, y) {
    return x.mul(WAD).div(y);
  }

  const [deployer, user1, user2] = accounts

  const [TWO, THREE, FOUR, EIGHT, NINE, TEN, THOUSAND] =
        [2, 3, 4, 8, 9, 10, 1000].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = EIGHT
  const oneEth = WAD
  const oneUsm = WAD
  const MINUTE = 60
  const HOUR = 60 * MINUTE
  const DAY = 24 * HOUR
  const priceWAD = wadDiv(price, TEN.pow(shift))

  describe("mints and burns a static amount", () => {
    let oracle, weth, usm

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })
      fum = await FUM.at(await usm.fum())

      await weth.deposit({ from: user1, value: oneEth.mul(TEN) })
      await weth.approve(usm.address, oneEth.mul(TEN), { from: user1 })

      let snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']
    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe("deployment", () => {
      it("starts with correct fum price", async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        // The FUM price should start off equal to $1, in ETH terms = 1 / price:
        fumBuyPrice.toString().should.equal(wadDiv(WAD, priceWAD).toString())
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumSellPrice.toString().should.equal(fumBuyPrice.toString())
      })
    })

    describe("minting and burning", () => {
      it("doesn't allow minting USM before minting FUM", async () => {
        await expectRevert(usm.mint(user1, user2, oneEth, { from: user1 }), "Fund before minting")
      })

      it("allows minting FUM", async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumBuyPrice.toString().should.equal(fumSellPrice.toString()) // We should start with the buy & sell FUM prices equal

        await usm.fund(user1, user2, oneEth, { from: user1 })
        const ethPool2 = (await weth.balanceOf(usm.address))
        ethPool2.toString().should.equal(oneEth.toString())

        const fumBalance2 = (await fum.balanceOf(user2))
        // The very first call to fund() is special: the initial price of $1 is used for the full trade, no sliding prices.  So
        // 1 ETH @ $250 should buy 250 FUM:
        fumBalance2.toString().should.equal(wadMul(oneEth, priceWAD).toString())

        const fundDefundAdj2 = (await usm.fundDefundAdjustment())
        fundDefundAdj2.toString().should.equal(WAD.toString()) // First call to fund() doesn't move the fundDefundAdjustment

        const fumBuyPrice2 = (await usm.fumPrice(sides.BUY))
        fumBuyPrice2.toString().should.equal(fumBuyPrice.toString()) // First fund() (w/o sliding prices) doesn't change FUM price
        const fumSellPrice2 = (await usm.fumPrice(sides.SELL))
        fumSellPrice2.toString().should.equal(fumSellPrice.toString())

        await usm.fund(user1, user2, oneEth, { from: user1 })
        const ethPool3 = (await weth.balanceOf(usm.address))
        ethPool3.toString().should.equal(oneEth.mul(TWO).toString())

        const fumBalance3 = (await fum.balanceOf(user2))
        // Calls to fund() after the first start using sliding prices.  In particular, following the math in USM.fumFromFund(),
        // with the second call here 2xing the pool (1 ETH -> 2) and the initial FUM price of $1 = 0.004 ETH, the FUM added should
        // be 1 (current ETH pool) / 0.004 * (1 - 1 / 2) = 125, ie, the user's FUM balance should increase by a factor of 3/2:
        fumBalance3.toString().should.equal(wadMul(oneEth, priceWAD).mul(THREE).div(TWO).toString())

        const fundDefundAdj3 = (await usm.fundDefundAdjustment())
        // We've 2x'd the ETH pool, which according to the adjustment math in USM.fund(), should 4x the fundDefundAdjustment:
        const targetFundDefundAdj3 = WAD.mul(FOUR)
        fundDefundAdj3.toString().should.equal(targetFundDefundAdj3.toString())

        const fumBuyPrice3 = (await usm.fumPrice(sides.BUY))
        const fumSellPrice3 = (await usm.fumPrice(sides.SELL))
        // The FUM buy & sell prices will have changed now, because the sliding-price above will have effectively collected fees
        // in the contract, which go to FUM holders.  Calculating the increase would be a bit of work, but one simple check we can
        // apply is, fundDefundAdjustment = 4 should mean the FUM buy price is now 4x the FUM sell price:
        fumBuyPrice3.toString().should.equal(wadMul(fumSellPrice3, fundDefundAdj3).toString())
      })

      describe("with existing FUM supply", () => {
        beforeEach(async () => {
          await usm.fund(user1, user1, oneEth, { from: user1 })
        })

        it("decays fundDefundAdjustment over time", async () => {
          // Check that fundDefundAdjustment decays properly (well, approximately) over time:
          // - Our adjustment was previously 4: see targetFundDefundAdj3 above.
          // - Use timeMachine to move forward 180 secs = 3 min.
          // - Since USM.BUY_SELL_ADJUSTMENTS_HALF_LIFE = 60 (1 min), 3 min should mean a decay of ~1/8.
          // - The way our "time decay towards 1" approximation works, decaying 4 by ~1/8 should yield 1 + (4 * 1/8) - 1/8 = 1.375.
          //   (See comment in USM.mintBurnAdjustment().)
          // - And finally - since our decay's exponentiation is approximate (WadMath.wadHalfExp()), don't compare fundDefundAdj4 to
          //   targetFundDefundAdj4 *exactly*, but instead first round both to the nearest multiple of 10 (via divRound(10)).
          const fundDefundAdj3 = (await usm.fundDefundAdjustment())

          const block0 = (await web3.eth.getBlockNumber())
          const t0 = (await web3.eth.getBlock(block0)).timestamp
          const timeDelay = 3 * 60
          await timeMachine.advanceTimeAndBlock(timeDelay)
          const block1 = (await web3.eth.getBlockNumber())
          const t1 = (await web3.eth.getBlock(block1)).timestamp
          t1.toString().should.equal((t0 + timeDelay).toString())
          const fundDefundAdj4 = (await usm.fundDefundAdjustment())
          const decayFactor4 = WAD.div(EIGHT)
          const targetFundDefundAdj4 = WAD.add(wadMul(fundDefundAdj3, decayFactor4)).sub(decayFactor4)
          fundDefundAdj4.divRound(TEN).toString().should.equal(targetFundDefundAdj4.divRound(TEN).toString())
        })

        it("allows minting USM", async () => {
          await usm.mint(user1, user2, oneEth, { from: user1 })
          const ethPool2 = (await weth.balanceOf(usm.address))
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = (await usm.balanceOf(user2))
          // Verify that sliding prices are working: this mirrors the sliding FUM prices above - see the math in USM.usmFromMint(),
          // with mint() here 2xing the pool (1 ETH from fund() earlier -> 2) and the initial USM price of $1 = 0.004 ETH, the USM
          // added should be 1 (current ETH pool) / 0.004 * (1 - 1 / 2) = 125 (ie, the ETH price $250 / 2):
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD).div(TWO).toString())

          const mintBurnAdj2 = (await usm.mintBurnAdjustment())
          // We've 2x'd the ETH pool, which according to the adjustment math in USM.mint(), should 0.25x the mintBurnAdjustment:
          mintBurnAdj2.toString().should.equal(WAD.div(FOUR).toString())

          const fumBuyPrice2 = (await usm.fumPrice(sides.BUY))
          const fumSellPrice2 = (await usm.fumPrice(sides.SELL))
          // FUM buy price should be unaffected (fundamentally, minting doesn't change the FUM price); but FUM sell price should
          // now have mintBurnAdjustment applied (since both adjustments apply to both USM and FUM price!), ie, be 1/4 buy price.
          // (Recall that mint() affects FUM *sell* price because minting (buying USM) and selling FUM are both "short ETH" ops.)
          fumSellPrice2.toString().should.equal(wadMul(fumBuyPrice2, mintBurnAdj2).toString())
        })

        describe("with existing USM supply", () => {
          beforeEach(async () => {
            await usm.mint(user1, user1, oneEth, { from: user1 })
          })

          it("decays mintBurnAdjustment over time", async () => {
            // Check that mintBurnAdjustment decays properly (well, approximately) over time:
            // - Our adjustment was previously 1/4: see mintBurnAdj2 above.
            // - Use timeMachine to move forward 180 secs = 3 min.
            // - Since USM.BUY_SELL_ADJUSTMENTS_HALF_LIFE = 60 (1 min), 3 min should mean a decay of ~1/8.
            // - The way our "time decay towards 1" approximation works, decaying 1/4 by ~1/8 should yield 1 + (1/4 * 1/8) - 1/8 = 0.90625.
            //   (See comment in USM.mintBurnAdjustment().)
            // - And finally - since our decay's exponentiation is approximate (WadMath.wadHalfExp()), don't compare mintBurnAdj3 to
            //   targetMintBurnAdj3 *exactly*, but instead first round both to the nearest multiple of 10 (via divRound(10)).
            const mintBurnAdj2 = (await usm.mintBurnAdjustment())

            const block0 = (await web3.eth.getBlockNumber())
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 3 * 60
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = (await web3.eth.getBlockNumber())
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            t1.toString().should.equal((t0 + timeDelay).toString())
            const mintBurnAdj3 = (await usm.mintBurnAdjustment())
            const decayFactor3 = WAD.div(EIGHT)
            const targetMintBurnAdj3 = WAD.add(wadMul(mintBurnAdj2, decayFactor3)).sub(decayFactor3)
            mintBurnAdj3.divRound(TEN).toString().should.equal(targetMintBurnAdj3.divRound(TEN).toString())
          })

          it("allows burning FUM", async () => {
            const ethPool = (await usm.ethPool())
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const fumBalance = (await fum.balanceOf(user1))
            const targetFumBalance = wadMul(oneEth, priceWAD) // see "allows minting FUM" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const debtRatio = (await usm.debtRatio())
            debtRatio.toString().should.equal(WAD.div(FOUR).toString()) // debt ratio should be 25% before we defund

            const fumToBurn = priceWAD.div(TWO)
            await usm.defund(user1, user2, fumToBurn, { from: user1 }) // defund 50% of our FUM
            const fumBalance2 = (await fum.balanceOf(user1))
            fumBalance2.toString().should.equal(fumBalance.sub(fumToBurn).toString())

            const ethOut = (await weth.balanceOf(user2))
            // Calculate targetEthOut using the math in USM.ethFromDefund():
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(fumToBurn, fumSellPrice))))
            // Compare approximately (to nearest multiple of 10) - may be a bit off due to rounding:
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())

            const debtRatio2 = (await usm.debtRatio())
            // Debt ratio should now be the 0.5 ETH's worth of USM, divided by the total left in the pool:
            const usmSupply = (await usm.totalSupply())
            const targetDebtRatio2 = wadDiv(wadDiv(usmSupply, priceWAD), ethPool.sub(ethOut))
            debtRatio2.toString().should.equal(targetDebtRatio2.toString())

            // Several other checks we could do here:
            // - The change (decrease, since we've sold FUM) in fundDefundAdjustment
            // - The corresponding decrease in FUM buy/sell prices (plus the increase from sliding-price fees collected above)
            // - Whether the fundDefundAdjustment decays properly over time (see "allows minting FUM" test above)
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            const MAX_DEBT_RATIO = (await usm.MAX_DEBT_RATIO())
            // Keep defunding most of our remaining FUM until we push debt ratio > MAX_DEBT_RATIO.  We have to defund repeatedly
            // because if we try to defund all in one shot (ie, without waiting for fundDefundAdjustment to decay back to 1), the
            // sliding FUM price means we don't actually go underwater.  This is by design - sliding prices keep us above water!

            const debtRatio0 = (await usm.debtRatio())
            debtRatio0.toString().should.equal(WAD.div(FOUR).toString()) // Should start at exactly 25.0%
            const fumBalance0 = (await fum.balanceOf(user1))

            await timeMachine.advanceTimeAndBlock(3600)
            await usm.defund(user1, user2, fumBalance0.mul(NINE).div(TEN), { from: user1 }) // defund 90% of our FUM
            const debtRatio1 = (await usm.debtRatio())
            debtRatio1.divRound(WAD.div(THOUSAND)).toString().should.equal('419') // Should be approx 41.9%
            const fumBalance1 = (await fum.balanceOf(user1))

            await timeMachine.advanceTimeAndBlock(3600)
            await usm.defund(user1, user2, fumBalance1.mul(NINE).div(TEN), { from: user1 }) // defund 90% of our FUM
            const debtRatio2 = (await usm.debtRatio())
            debtRatio2.divRound(WAD.div(THOUSAND)).toString().should.equal('638') // Should be approx 63.8%
            const fumBalance2 = (await fum.balanceOf(user1))

            await timeMachine.advanceTimeAndBlock(3600)
            await expectRevert(
              usm.defund(user1, user2, fumBalance2.mul(NINE).div(TEN), { from: user1 }), // try to defund 90% of our FUM - but should fail now
              "Max debt ratio breach"
            )
          })

          it("allows burning USM", async () => {
            const ethPool = (await usm.ethPool())
            const usmSellPrice = (await usm.usmPrice(sides.SELL))

            const usmToBurn = (await usm.balanceOf(user1))
            await usm.burn(user1, user2, usmToBurn, { from: user1 })
            const usmBalance2 = (await usm.balanceOf(user1))
            usmBalance2.toString().should.equal('0')

            const ethOut = (await weth.balanceOf(user2))
            // Calculate targetEthOut using the math in USM.ethFromBurn():
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(usmToBurn, usmSellPrice))))
            // Compare approximately (to nearest multiple of 10) - may be a bit off due to rounding:
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())

            const debtRatio2 = (await usm.debtRatio())
            debtRatio2.toString().should.equal('0') // debt ratio should be 0% - we burned all the debt!
          })

          it("doesn't allow burning USM if debt ratio over 100%", async () => {
            const debtRatio = (await usm.debtRatio())
            debtRatio.toString().should.equal(WAD.div(FOUR).toString())

            const priceDecreaseFactor = EIGHT
            await oracle.setPrice(price.div(priceDecreaseFactor)) // Reducing the ETH price pushes up the debt ratio
            const debtRatio2 = (await usm.debtRatio())
            debtRatio2.toString().should.equal(debtRatio.mul(priceDecreaseFactor).toString())

            await expectRevert(usm.burn(user1, user2, oneUsm, { from: user1 }), "Debt ratio too high")
          })

          it("reduces minFumBuyPrice over time", async () => {
            const debtRatio = (await usm.debtRatio())
            debtRatio.toString().should.equal(WAD.div(FOUR).toString())
            const minFumBuyPrice = (await usm.minFumBuyPrice())
            minFumBuyPrice.toString().should.equal('0')

            const priceDecreaseFactor = EIGHT
            await oracle.setPrice(price.div(priceDecreaseFactor)) // Reducing the ETH price pushes up the debt ratio
            const debtRatio2 = (await usm.debtRatio())
            debtRatio2.toString().should.equal(debtRatio.mul(priceDecreaseFactor).toString())

            // Calculate targetMinFumBuyPrice using the math in USM._updateMinFumBuyPrice():
            const MAX_DEBT_RATIO = (await usm.MAX_DEBT_RATIO())
            const ethPool = (await usm.ethPool())
            const fumSupply = (await fum.totalSupply())
            const targetMinFumBuyPrice2 = wadDiv(wadMul(WAD.sub(MAX_DEBT_RATIO), ethPool), fumSupply)

            // Make one tiny call to fund(), just to actually trigger the internal call to _updateMinFumBuyPrice():
            await usm.fund(user1, user1, oneEth.div(THOUSAND), { from: user1 })

            const minFumBuyPrice2 = (await usm.minFumBuyPrice())
            minFumBuyPrice2.toString().should.equal(targetMinFumBuyPrice2.toString())

            // Now move forward a few days, and check that minFumBuyPrice decays by the appropriate factor:
            const block0 = (await web3.eth.getBlockNumber())
            const t0 = (await web3.eth.getBlock(block0)).timestamp
            const timeDelay = 3 * DAY
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = (await web3.eth.getBlockNumber())
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            t1.toString().should.equal((t0 + timeDelay).toString())
            const minFumBuyPrice3 = (await usm.minFumBuyPrice())
            const decayFactor3 = WAD.div(EIGHT)
            const targetMinFumBuyPrice3 = wadMul(minFumBuyPrice2, decayFactor3)
            minFumBuyPrice3.toString().should.equal(targetMinFumBuyPrice3.toString())
            //console.log("MFBP 2: " + minFumBuyPrice + ", " + targetMinFumBuyPrice2 + ", " + minFumBuyPrice2 + ", " + targetMinFumBuyPrice3 + ", " + minFumBuyPrice3)
          })
        })
      })
    })
  })
})
