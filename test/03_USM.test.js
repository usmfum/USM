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

  function wadSquared(x) {
    return x.mul(x).div(WAD);
  }

  function wadDiv(x, y) {
    return x.mul(WAD).div(y);
  }

  function wadDecay(adjustment, decayFactor) {
    return WAD.add(wadMul(adjustment, decayFactor)).sub(decayFactor)
  }

  function shouldEqualApprox(x, y, precision) {
    x.sub(y).abs().should.be.bignumber.lte(precision)
  }

  const [deployer, user1, user2, user3] = accounts

  const [ONE, TWO, THREE, FOUR, EIGHT, TEN, HUNDRED, THOUSAND] =
        [1, 2, 3, 4, 8, 10, 100, 1000].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = EIGHT
  const oneEth = WAD
  const oneUsm = WAD
  const oneFum = WAD
  const MINUTE = 60
  const HOUR = 60 * MINUTE
  const DAY = 24 * HOUR
  const priceWAD = wadDiv(price, TEN.pow(shift))

  describe("mints and burns a static amount", () => {
    let oracle, weth, usm, totalEthToFund, totalEthToMint, bitOfEth

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })
      fum = await FUM.at(await usm.fum())

      totalEthToFund = oneEth.mul(FOUR)
      await weth.deposit({ from: user1, value: totalEthToFund })
      await weth.approve(usm.address, totalEthToFund, { from: user1 })

      totalEthToMint = oneEth.mul(TEN)
      await weth.deposit({ from: user2, value: totalEthToMint })
      await weth.approve(usm.address, totalEthToMint, { from: user2 })

      bitOfEth = oneEth.div(THOUSAND)
      await weth.deposit({ from: user3, value: bitOfEth })
      await weth.approve(usm.address, bitOfEth, { from: user3 })

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
        await expectRevert(usm.mint(user2, user1, oneEth, { from: user2 }), "Fund before minting")
      })

      it("allows minting FUM", async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumBuyPrice.toString().should.equal(fumSellPrice.toString()) // We should start with the buy & sell FUM prices equal

        const ethIn = totalEthToFund.div(TWO) // pass in half of the WETH to fund() here, the other half below
        await usm.fund(user1, user2, ethIn, { from: user1 })
        const ethPool2 = (await usm.ethPool())
        ethPool2.toString().should.equal(ethIn.toString())

        const fumBalance2 = (await fum.balanceOf(user2))
        // The very first call to fund() is special: the initial price of $1 is used for the full trade, no sliding price.  So
        // 1 ETH @ $250 should buy 250 FUM:
        fumBalance2.toString().should.equal(wadMul(ethIn, priceWAD).toString())

        const fundDefundAdj2 = (await usm.fundDefundAdjustment())
        fundDefundAdj2.toString().should.equal(WAD.toString()) // First call to fund() doesn't move the fundDefundAdjustment

        const fumBuyPrice2 = (await usm.fumPrice(sides.BUY))
        fumBuyPrice2.toString().should.equal(fumBuyPrice.toString()) // First fund() (w/o sliding prices) doesn't change FUM price
        const fumSellPrice2 = (await usm.fumPrice(sides.SELL))
        fumSellPrice2.toString().should.equal(fumSellPrice.toString())

        await usm.fund(user1, user2, ethIn, { from: user1 }) // pass in the second half of user1's WETH
        const ethPool3 = (await usm.ethPool())
        ethPool3.toString().should.equal(ethIn.mul(TWO).toString())

        const fumBalance3 = (await fum.balanceOf(user2))
        // Calls to fund() after the first start using sliding prices.  In particular, following the math in USM.fumFromFund(),
        // with the second call here 2xing the (W)ETH pool and the initial FUM price of $1 = 0.004 ETH, the FUM added should be
        // (current ETH pool) / 0.004 * (1 - 1 / 2), ie, the user's FUM balance should increase by a factor of 3/2:
        fumBalance3.toString().should.equal(wadMul(ethIn, priceWAD).mul(THREE).div(TWO).toString())

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
          await usm.fund(user1, user2, totalEthToFund, { from: user1 })
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
          const timeDelay = 3 * MINUTE
          await timeMachine.advanceTimeAndBlock(timeDelay)
          const block1 = (await web3.eth.getBlockNumber())
          const t1 = (await web3.eth.getBlock(block1)).timestamp
          t1.toString().should.equal((t0 + timeDelay).toString())
          const fundDefundAdj4 = (await usm.fundDefundAdjustment())
          const decayFactor4 = wadDiv(ONE, EIGHT)
          const targetFundDefundAdj4 = wadDecay(fundDefundAdj3, decayFactor4)
          shouldEqualApprox(fundDefundAdj4, targetFundDefundAdj4, TEN)
        })

        it("allows minting USM", async () => {
          const ethPool = (await usm.ethPool())
          ethPool.toString().should.equal(totalEthToFund.toString())

          const mintBurnAdj = (await usm.mintBurnAdjustment())
          mintBurnAdj.toString().should.equal(WAD.toString()) // Before our first mint()/burn(), mintBurnAdjustment should be 1

          await usm.mint(user2, user1, totalEthToMint, { from: user2 })
          const ethPool2 = (await usm.ethPool())
          ethPool2.toString().should.equal(totalEthToFund.add(totalEthToMint).toString())

          const usmBalance2 = (await usm.balanceOf(user1))
          // Verify that sliding prices are working - this mirrors the sliding FUM price above.  Per the math in
          // USM.usmFromMint(), with mint() here increasing the ETH pool by a factor of f = (fund ETH + mint ETH) / fund ETH, and
          // the initial USM price of $1 = 0.004 ETH = 1 / $250, the USM added should be ETH pool * 250 * (1 - f):
          const poolIncreaseFactor = wadDiv(ethPool2, ethPool)
          const targetUsmBalance2 = wadMul(wadMul(ethPool, priceWAD), WAD.sub(wadDiv(WAD, poolIncreaseFactor)))
          usmBalance2.toString().should.equal(targetUsmBalance2.toString())

          const mintBurnAdj2 = (await usm.mintBurnAdjustment())
          // According to the adjustment math in USM.mint(), if the ETH pool has changed by factor f, the mintBurnAdjustment
          // should now be 1/(f**2):
          const targetMintBurnAdj2 = wadDiv(WAD, wadSquared(poolIncreaseFactor))
          shouldEqualApprox(mintBurnAdj2, targetMintBurnAdj2, TEN)

          const fumBuyPrice2 = (await usm.fumPrice(sides.BUY))
          const fumSellPrice2 = (await usm.fumPrice(sides.SELL))
          // FUM buy price should be unaffected (fundamentally, minting doesn't change the FUM price); but FUM sell price should
          // now have mintBurnAdjustment applied (since both adjustments apply to both USM and FUM price!), ie, be 1/4 buy price.
          // (Recall that mint() affects FUM *sell* price because minting (buying USM) and selling FUM are both "short ETH" ops.)
          fumSellPrice2.toString().should.equal(wadMul(fumBuyPrice2, mintBurnAdj2).toString())
        })

        describe("with existing USM supply", () => {
          beforeEach(async () => {
            await usm.mint(user2, user1, totalEthToMint, { from: user2 })
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
            const timeDelay = 3 * MINUTE
            await timeMachine.advanceTimeAndBlock(timeDelay)
            const block1 = (await web3.eth.getBlockNumber())
            const t1 = (await web3.eth.getBlock(block1)).timestamp
            t1.toString().should.equal((t0 + timeDelay).toString())
            const mintBurnAdj3 = (await usm.mintBurnAdjustment())
            const decayFactor3 = wadDiv(ONE, EIGHT)
            const targetMintBurnAdj3 = wadDecay(mintBurnAdj2, decayFactor3)
            shouldEqualApprox(mintBurnAdj3, targetMintBurnAdj3, TEN)
          })

          it("allows burning FUM", async () => {
            const ethPool = (await usm.ethPool())
            const targetEthPool = totalEthToFund.add(totalEthToMint) // Should be the total of ETH added: one fund() + one fund()
            ethPool.toString().should.equal(targetEthPool.toString())

            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const fumBalance = (await fum.balanceOf(user2))
            const targetFumBalance = wadMul(totalEthToFund, priceWAD) // see "allows minting FUM"/"with existing FUM supply" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const debtRatio = (await usm.debtRatio())
            const usmSupply = (await usm.totalSupply())
            const targetDebtRatio = wadDiv(usmSupply, wadMul(ethPool, priceWAD))
            shouldEqualApprox(debtRatio, targetDebtRatio, TEN)

            const fumToBurn = fumBalance.div(FOUR) // defund 25% of our FUM
            await usm.defund(user2, user1, fumToBurn, { from: user2 })
            const fumBalance2 = (await fum.balanceOf(user2))
            fumBalance2.toString().should.equal(fumBalance.sub(fumToBurn).toString())

            const ethOut = (await weth.balanceOf(user1))
            // Calculate targetEthOut using the math in USM.ethFromDefund():
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(fumToBurn, fumSellPrice))))
            // Compare approximately (to nearest multiple of 10) - may be a bit off due to rounding:
            shouldEqualApprox(ethOut, targetEthOut, TEN)

            const debtRatio2 = (await usm.debtRatio())
            // Debt ratio should now be the same USM-value as in targetDebtRatio above, divided by a reduced total ETH pool:
            const targetDebtRatio2 = wadDiv(usmSupply, wadMul(ethPool.sub(ethOut), priceWAD))
            shouldEqualApprox(debtRatio2, targetDebtRatio2, TEN)

            // Several other checks we could do here:
            // - The change (decrease, since we've sold FUM) in fundDefundAdjustment
            // - The corresponding decrease in FUM buy/sell prices (plus the increase from sliding-price fees collected above)
            // - Whether the fundDefundAdjustment decays properly over time (see "allows minting FUM" test above)
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            const MAX_DEBT_RATIO = (await usm.MAX_DEBT_RATIO())
            const debtRatio0 = (await usm.debtRatio())
            const price0 = (await oracle.latestPrice())

            // Move price to get debt ratio just *below* MAX.  Eg, if debt ratio is currently 156%, increasing the price by
            // (156% / 79%%) should bring debt ratio to just about 79%:
            const targetDebtRatio1 = MAX_DEBT_RATIO.sub(WAD.div(HUNDRED)) // Eg, 80% - 1% = 79%
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1)
            const targetPrice1 = wadMul(price0, priceChangeFactor1)
            await oracle.setPrice(targetPrice1)
            const price1 = (await oracle.latestPrice())
            price1.toString().should.equal(targetPrice1.toString())
            const debtRatio1 = (await usm.debtRatio())
            debtRatio1.should.be.bignumber.lt(MAX_DEBT_RATIO)

            // Now this tiny defund() should succeed:
            await usm.defund(user2, user1, oneFum, { from: user2 })
            const debtRatio2 = (await usm.debtRatio())

            // Next, similarly move price to get debt ratio just *above* MAX:
            const targetDebtRatio3 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3)
            const targetPrice3 = wadMul(price1, priceChangeFactor3)
            await oracle.setPrice(targetPrice3)
            const price3 = (await oracle.latestPrice())
            price3.toString().should.equal(targetPrice3.toString())
            const debtRatio3 = (await usm.debtRatio())
            debtRatio3.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // And now defund() should fail:
            await expectRevert(usm.defund(user2, user1, oneFum, { from: user2 }), "Max debt ratio breach")
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
            shouldEqualApprox(ethOut, targetEthOut, TEN)

            const debtRatio2 = (await usm.debtRatio())
            debtRatio2.toString().should.equal('0') // debt ratio should be 0% - we burned all the debt!
          })

          it("doesn't allow burning USM if debt ratio over 100%", async () => {
            const debtRatio0 = (await usm.debtRatio())
            const price0 = (await oracle.latestPrice())

            // Move price to get debt ratio just *below* 100%:
            const targetDebtRatio1 = WAD.mul(HUNDRED.sub(ONE)).div(HUNDRED) // 99%
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1)
            const targetPrice1 = wadMul(price0, priceChangeFactor1)
            await oracle.setPrice(targetPrice1)
            const price1 = (await oracle.latestPrice())
            price1.toString().should.equal(targetPrice1.toString())
            const debtRatio1 = (await usm.debtRatio())
            debtRatio1.should.be.bignumber.lt(WAD)

            // Now this tiny burn() should succeed:
            await usm.burn(user1, user2, oneUsm, { from: user1 })
            const debtRatio2 = (await usm.debtRatio())

            // Next, similarly move price to get debt ratio just *above* 100%:
            const targetDebtRatio3 = WAD.mul(HUNDRED.add(ONE)).div(HUNDRED) // 101%
            const priceChangeFactor3 = wadDiv(debtRatio2, targetDebtRatio3)
            const targetPrice3 = wadMul(price1, priceChangeFactor3)
            await oracle.setPrice(targetPrice3)
            const price3 = (await oracle.latestPrice())
            price3.toString().should.equal(targetPrice3.toString())
            const debtRatio3 = (await usm.debtRatio())
            debtRatio3.should.be.bignumber.gt(WAD)

            // And now the same burn() should fail:
            await expectRevert(usm.burn(user1, user2, oneUsm, { from: user1 }), "Debt ratio too high")
          })

          it("reduces minFumBuyPrice over time", async () => {
            const MAX_DEBT_RATIO = (await usm.MAX_DEBT_RATIO())
            const debtRatio0 = (await usm.debtRatio())
            const price0 = (await oracle.latestPrice())

            // Move price to get debt ratio just *above* MAX:
            const targetDebtRatio1 = MAX_DEBT_RATIO.add(WAD.div(HUNDRED)) // Eg, 80% + 1% = 81%
            const priceChangeFactor1 = wadDiv(debtRatio0, targetDebtRatio1)
            const targetPrice1 = wadMul(price0, priceChangeFactor1)
            await oracle.setPrice(targetPrice1)
            const price1 = (await oracle.latestPrice())
            price1.toString().should.equal(targetPrice1.toString())
            const debtRatio1 = (await usm.debtRatio())
            debtRatio1.should.be.bignumber.gt(MAX_DEBT_RATIO)

            // Calculate targetMinFumBuyPrice using the math in USM._updateMinFumBuyPrice():
            const ethPool = (await usm.ethPool())
            const fumSupply = (await fum.totalSupply())
            const targetMinFumBuyPrice2 = wadDiv(wadMul(WAD.sub(MAX_DEBT_RATIO), ethPool), fumSupply)

            // Make one tiny call to fund(), just to actually trigger the internal call to _updateMinFumBuyPrice():
            await usm.fund(user3, user3, bitOfEth, { from: user3 })

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
            const decayFactor3 = wadDiv(ONE, EIGHT)
            const targetMinFumBuyPrice3 = wadMul(minFumBuyPrice2, decayFactor3)
            minFumBuyPrice3.toString().should.equal(targetMinFumBuyPrice3.toString())
            //console.log("MFBP 2: " + minFumBuyPrice + ", " + targetMinFumBuyPrice2 + ", " + minFumBuyPrice2 + ", " + targetMinFumBuyPrice3 + ", " + minFumBuyPrice3)
          })
        })
      })
    })
  })
})
