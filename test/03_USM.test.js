const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')
const TestOracle = artifacts.require('./TestOracle.sol')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  let [deployer, user] = accounts

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = new BN('8')
  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const oneEth = WAD
  const oneUsm = WAD
  const priceWAD = WAD.mul(price).div(new BN('10').pow(shift))

  describe('mints and burns a static amount', () => {
    let oracle, usm

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      usm = await USM.new(oracle.address, { from: deployer })
      fum = await FUM.at(await usm.fum())
    })

    describe('deployment', () => {
      it('starts with correct fum buy price', async () => {
        let fumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
        // The fum price should start off equal to $1, in ETH terms = 1 / price:
        fumBuyPrice.should.equal(WAD.mul(WAD).div(priceWAD).toString())
      })
    })

    describe('minting and burning', () => {
      it("doesn't allow minting USM before minting FUM", async () => {
        await expectRevert(usm.mint({ from: user, value: oneEth }), 'Fund before minting')
      })

      it('allows minting FUM', async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
        const fumSellPrice = (await usm.fumPrice(sides.SELL)).toString()

        await usm.fund({ from: user, value: oneEth })
        const fumBalance = (await fum.balanceOf(user)).toString()
        fumBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString()) // after funding we should have eth_price fum per eth passed in

        const newEthPool = (await web3.eth.getBalance(usm.address)).toString()
        newEthPool.should.equal(oneEth.toString())

        const newFumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
        newFumBuyPrice.should.equal(fumBuyPrice) // Funding doesn't change the fum price
        const newFumSellPrice = (await usm.fumPrice(sides.SELL)).toString()
        newFumSellPrice.should.equal(fumSellPrice)
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await usm.fund({ from: user, value: oneEth })
        })

        it('allows minting USM', async () => {
          const fumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
          const fumSellPrice = (await usm.fumPrice(sides.SELL)).toString()

          await usm.mint({ from: user, value: oneEth })
          const usmBalance = (await usm.balanceOf(user)).toString()
          usmBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString())

          const newFumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
          newFumBuyPrice.should.equal(fumBuyPrice) // Minting doesn't change the fum price if buffer is 0
          const newFumSellPrice = (await usm.fumPrice(sides.SELL)).toString()
          newFumSellPrice.should.equal(fumSellPrice)
        })

        it("doesn't allow minting with less than MIN_ETH_AMOUNT", async () => {
          const MIN_ETH_AMOUNT = await usm.MIN_ETH_AMOUNT()
          // TODO: assert MIN_ETH_AMOUNT > 0
          await expectRevert(usm.mint({ from: user, value: MIN_ETH_AMOUNT.sub(new BN('1')) }), '0.001 ETH minimum')
        })

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await usm.mint({ from: user, value: oneEth })
          })

          it('allows burning FUM', async () => {
            const fumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
            const fumSellPrice = (await usm.fumPrice(sides.SELL)).toString()

            const fumBalance = (await fum.balanceOf(user)).toString()
            const targetFumBalance = oneEth.mul(priceWAD).div(WAD) // see "allows minting FUM" above
            fumBalance.should.equal(targetFumBalance.toString())

            const debtRatio = (await usm.debtRatio()).toString()
            debtRatio.should.equal(WAD.div(new BN('2')).toString()) // debt ratio should be 50% before we defund

            await usm.defund(priceWAD.mul(new BN('3')).div(new BN('4')), { from: user }) // defund 75% of our fum
            const newFumBalance = (await fum.balanceOf(user)).toString()
            newFumBalance.should.equal(targetFumBalance.div(new BN('4')).toString()) // should be 25% of what it was

            const newDebtRatio = (await usm.debtRatio()).toString()
            newDebtRatio.should.equal(WAD.mul(new BN('4')).div(new BN('5')).toString()) // debt ratio should now be 80%

            const newFumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
            newFumBuyPrice.should.equal(fumBuyPrice) // Defunding doesn't change the fum price
            const newFumSellPrice = (await usm.fumPrice(sides.SELL)).toString()
            newFumSellPrice.should.equal(fumSellPrice)
          })

          it("doesn't allow burning FUM if it would push debt ratio above MAX_DEBT_RATIO", async () => {
            await expectRevert(
              usm.defund(priceWAD.mul(new BN('7')).div(new BN('8')), { from: user }), // try to defund 7/8 = 87.5% of our fum
              'Max debt ratio breach'
            )
          })

          it('allows burning USM', async () => {
            const usmBalance = (await usm.balanceOf(user)).toString()
            const fumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
            const fumSellPrice = (await usm.fumPrice(sides.SELL)).toString()

            await usm.burn(usmBalance, { from: user })
            const newUsmBalance = (await usm.balanceOf(user)).toString()
            newUsmBalance.should.equal('0')
            // TODO: Test the eth balance just went up. Try setting gas price to zero for an exact amount

            const newFumBuyPrice = (await usm.fumPrice(sides.BUY)).toString()
            newFumBuyPrice.should.equal(fumBuyPrice) // Burning doesn't change the fum price if buffer is 0
            const newFumSellPrice = (await usm.fumPrice(sides.SELL)).toString()
            newFumSellPrice.should.equal(fumSellPrice)
          })

          it("doesn't allow burning USM with less than MIN_BURN_AMOUNT", async () => {
            const MIN_BURN_AMOUNT = await usm.MIN_BURN_AMOUNT()
            // TODO: assert MIN_BURN_AMOUNT > 0
            await expectRevert(usm.burn(MIN_BURN_AMOUNT.sub(new BN('1')), { from: user }), '1 USM minimum')
          })

          it("doesn't allow burning USM if debt ratio under 100%", async () => {
            const debtRatio = (await usm.debtRatio()).toString()
            const factor = new BN('2')
            debtRatio.should.equal(WAD.div(factor).toString())

            await oracle.setPrice(price.div(factor).div(factor)) // Dropping eth prices will push up the debt ratio
            const newDebtRatio = (await usm.debtRatio()).toString()
            newDebtRatio.should.equal(WAD.mul(factor).toString())

            await expectRevert(usm.burn(oneUsm, { from: user }), 'Debt ratio too high')
          })
        })
      })
    })
  })
})
