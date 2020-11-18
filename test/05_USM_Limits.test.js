const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')

const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Limits', (accounts) => {
  let [deployer, user1] = accounts

  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const ethTypes = { ETH: 0, WETH: 1 }
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const oneUsm = WAD
  const price = new BN(250)
  const priceWAD = price.mul(WAD)

  describe('mints and burns a static amount', () => {
    let weth, usm

    beforeEach(async () => {
      // Deploy contracts
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(weth.address, priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())

      await weth.deposit({ from: user1, value: oneEth.mul(new BN('2')) })
      await weth.approve(usm.address, MAX, { from: user1 })
    })

    describe('minting and burning', () => {

      it('allows minting FUM', async () => {

        await usm.fundLimit(oneEth, 0, ethTypes.WETH, { from: user1 })

        const newEthPool = (await weth.balanceOf(usm.address))
        newEthPool.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          usm.fundLimit(oneEth, MAX, ethTypes.WETH, { from: user1 }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await usm.fundLimit(oneEth, 0, ethTypes.WETH, { from: user1 })
        })

        it('allows minting USM', async () => {
          await usm.mintLimit(oneEth, 0, ethTypes.WETH, { from: user1 })
          const usmBalance = (await usm.balanceOf(user1))
          usmBalance.toString().should.equal(oneEth.mul(priceWAD).div(WAD).toString())
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            usm.mintLimit(oneEth, MAX, ethTypes.WETH, { from: user1 }),
            "Limit not reached",
          )
        })  

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await usm.mintLimit(oneEth, 0, ethTypes.WETH, { from: user1 })
          })

          it('allows burning FUM', async () => {
            const targetFumBalance = oneEth.mul(priceWAD).div(WAD) // see "allows minting FUM" above
            const startingBalance = await weth.balanceOf(user1)

            await usm.defundLimit(priceWAD.mul(new BN('3')).div(new BN('4')), 0, ethTypes.WETH, { from: user1 }) // defund 75% of our fum
            const newFumBalance = (await fum.balanceOf(user1))
            newFumBalance.toString().should.equal(targetFumBalance.div(new BN('4')).toString()) // should be 25% of what it was

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn FUM if minimum not reached', async () => {
            await expectRevert(
              usm.defundLimit(priceWAD.mul(new BN('3')).div(new BN('4')), MAX, ethTypes.WETH, { from: user1 }),
              "Limit not reached",
            )
          })    

          it('allows burning USM', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()
            const startingBalance = await weth.balanceOf(user1)

            await usm.burnLimit(usmBalance, 0, ethTypes.WETH, { from: user1 })
            const newUsmBalance = (await usm.balanceOf(user1))
            newUsmBalance.toString().should.equal('0')

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()

            await expectRevert(
              usm.burnLimit(usmBalance, MAX, ethTypes.WETH, { from: user1 }),
              "Limit not reached",
            )
          })    
        })
      })
    })
  })
})
