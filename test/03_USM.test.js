const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  let [deployer, user1, user2] = accounts

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = new BN('8')
  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const oneEth = WAD
  const oneUsm = WAD
  const priceWAD = WAD.mul(price).div(new BN('10').pow(shift))

  describe('mints and burns a static amount', () => {
    let oracle, weth, usm

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })
      fum = await FUM.at(await usm.fum())

      await weth.deposit({ from: user1, value: WAD.mul(new BN('10')) })
      await weth.approve(usm.address, WAD.mul(new BN('10')), { from: user1 })
    })

    describe('deployment', () => {
      it('starts with correct fum buy price', async () => {
        let fumBuyPrice = (await usm.fumPrice(sides.BUY))
        // The fum price should start off equal to $1, in ETH terms = 1 / price:
        fumBuyPrice.toString().should.equal(WAD.mul(WAD).div(priceWAD).toString())
      })
    })

    describe('minting and burning', () => {
      it("doesn't allow minting USM before minting FUM", async () => {
        await expectRevert(usm.mint(user1, user2, oneEth, { from: user1 }), 'Fund before minting')
      })

      it('allows minting FUM', async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))

        await usm.fund(user1, user2, oneEth, { from: user1 })
        const fumBalance = (await fum.balanceOf(user2))
        fumBalance.toString().should.equal(oneEth.mul(priceWAD).div(WAD).toString()) // after funding we should have eth_price fum per eth passed in

        const newEthPool = (await weth.balanceOf(usm.address))
        newEthPool.toString().should.equal(oneEth.toString())

        const newFumBuyPrice = (await usm.fumPrice(sides.BUY))
        newFumBuyPrice.toString().should.equal(fumBuyPrice.toString()) // Funding doesn't change the fum price
        const newFumSellPrice = (await usm.fumPrice(sides.SELL))
        newFumSellPrice.toString().should.equal(fumSellPrice.toString())
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await usm.fund(user1, user1, oneEth, { from: user1 })
        })

        it('allows minting USM', async () => {
          const fumBuyPrice = (await usm.fumPrice(sides.BUY))
          const fumSellPrice = (await usm.fumPrice(sides.SELL))

          await usm.mint(user1, user2, oneEth, { from: user1 })
          const usmBalance = (await usm.balanceOf(user2))
          usmBalance.toString().should.equal(oneEth.mul(priceWAD).div(WAD).toString())

          const newFumBuyPrice = (await usm.fumPrice(sides.BUY))
          newFumBuyPrice.toString().should.equal(fumBuyPrice.toString()) // Minting doesn't change the fum price if buffer is 0
          const newFumSellPrice = (await usm.fumPrice(sides.SELL))
          newFumSellPrice.toString().should.equal(fumSellPrice.toString())
        })

        it("doesn't allow minting with less than MIN_ETH_AMOUNT", async () => {
          const MIN_ETH_AMOUNT = await usm.MIN_ETH_AMOUNT()
          // TODO: assert MIN_ETH_AMOUNT > 0
          await expectRevert(usm.mint(user1, user2, MIN_ETH_AMOUNT.sub(new BN('1')), { from: user1 }), '0.001 ETH minimum')
        })

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await usm.mint(user1, user1, oneEth, { from: user1 })
          })

          it('allows burning FUM', async () => {
            const fumBuyPrice = (await usm.fumPrice(sides.BUY))
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const fumBalance = (await fum.balanceOf(user1))
            const targetFumBalance = oneEth.mul(priceWAD).div(WAD) // see "allows minting FUM" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const debtRatio = (await usm.debtRatio())
            debtRatio.toString().should.equal(WAD.div(new BN('2')).toString()) // debt ratio should be 50% before we defund

            const fumToBurn = priceWAD.mul(new BN('3')).div(new BN('4'))
            await usm.defund(user1, user2, fumToBurn, { from: user1 }) // defund 75% of our fum
            const newFumBalance = (await fum.balanceOf(user1))
            newFumBalance.toString().should.equal(targetFumBalance.div(new BN('4')).toString()) // should be 25% of what it was

            const newEthBalance = (await weth.balanceOf(user2))
            newEthBalance.toString().should.equal(fumToBurn.mul(fumSellPrice).div(WAD).toString())

            const newDebtRatio = (await usm.debtRatio())
            newDebtRatio.toString().should.equal(WAD.mul(new BN('4')).div(new BN('5')).toString()) // debt ratio should now be 80%

            const newFumBuyPrice = (await usm.fumPrice(sides.BUY))
            newFumBuyPrice.toString().should.equal(fumBuyPrice.toString()) // Defunding doesn't change the fum price
            const newFumSellPrice = (await usm.fumPrice(sides.SELL))
            newFumSellPrice.toString().should.equal(fumSellPrice.toString())
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            await expectRevert(
              usm.defund(user1, user2, priceWAD.mul(new BN('7')).div(new BN('8')), { from: user1 }), // try to defund 7/8 = 87.5% of our fum
              'Max debt ratio breach'
            )
          })

          it('allows burning USM', async () => {
            const usmBalance = (await usm.balanceOf(user1))
            const fumBuyPrice = (await usm.fumPrice(sides.BUY))
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            await usm.burn(user1, user2, usmBalance, { from: user1 })
            const newUsmBalance = (await usm.balanceOf(user1))
            newUsmBalance.toString().should.equal('0')

            const newEthBalance = (await weth.balanceOf(user2))
            newEthBalance.toString().should.equal((await usm.usmToEth(usmBalance)).toString())

            const newFumBuyPrice = (await usm.fumPrice(sides.BUY))
            newFumBuyPrice.toString().should.equal(fumBuyPrice.toString()) // Burning doesn't change the fum price if buffer is 0
            const newFumSellPrice = (await usm.fumPrice(sides.SELL))
            newFumSellPrice.toString().should.equal(fumSellPrice.toString())
          })

          it("doesn't allow burning USM with less than MIN_BURN_AMOUNT", async () => {
            const MIN_BURN_AMOUNT = await usm.MIN_BURN_AMOUNT()
            // TODO: assert MIN_BURN_AMOUNT > 0
            await expectRevert(usm.burn(user1, user2, MIN_BURN_AMOUNT.sub(new BN('1')), { from: user1 }), '1 USM minimum')
          })

          it("doesn't allow burning USM if debt ratio under 100%", async () => {
            const debtRatio = (await usm.debtRatio())
            const factor = new BN('2')
            debtRatio.toString().should.equal(WAD.div(factor).toString())

            await oracle.setPrice(price.div(factor).div(factor)) // Dropping eth prices will push up the debt ratio
            const newDebtRatio = (await usm.debtRatio())
            newDebtRatio.toString().should.equal(WAD.mul(factor).toString())

            await expectRevert(usm.burn(user1, user2, oneUsm, { from: user1 }), 'Debt ratio too high')
          })
        })
      })
    })
  })
})
