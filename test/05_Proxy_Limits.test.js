const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')
const Proxy = artifacts.require('Proxy')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Limits', (accounts) => {
  let [deployer, user1, user2] = accounts

  const ZERO = new BN('0')
  const TWO = new BN('2')
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
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
      usm = await USM.new(priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())
      proxy = await Proxy.new(usm.address, weth.address, { from: deployer })

      await weth.deposit({ from: user1, value: oneEth.mul(TWO) }) // One 1-ETH fund() + one 1-ETH mint()
      await weth.approve(proxy.address, MAX, { from: user1 })
      await usm.addDelegate(proxy.address, { from: user1 })
    })

    describe('minting and burning', () => {

      it('allows minting FUM', async () => {

        await proxy.fund(user1, user1, oneEth, 0, { from: user1 })

        const newEthPool = await usm.ethPool()
        newEthPool.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          proxy.fund(user1, user1, oneEth, MAX, { from: user1 }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(user1, user1, oneEth, 0, { from: user1 })
        })

        it('allows minting USM', async () => {
          await proxy.mint(user1, user1, oneEth, 0, { from: user1 })
          const usmBalance = (await usm.balanceOf(user1))
          usmBalance.toString().should.equal(oneEth.mul(priceWAD).div(WAD).toString())
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            proxy.mint(user1, user1, oneEth, MAX, { from: user1 }),
            "Limit not reached",
          )
        })

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mint(user1, user1, oneEth, 0, { from: user1 })
          })

          it('allows burning FUM', async () => {
            const targetFumBalance = oneEth.mul(priceWAD).div(WAD) // see "allows minting FUM" above
            const startingBalance = await weth.balanceOf(user1)

            const fumToBurn = priceWAD.mul(new BN('3')).div(new BN('4'))
            await proxy.defund(user1, user1, fumToBurn, 0, { from: user1 }) // defund 75% of our fum
            const newFumBalance = (await fum.balanceOf(user1))
            newFumBalance.toString().should.equal(targetFumBalance.div(new BN('4')).toString()) // should be 25% of what it was

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn FUM if minimum not reached', async () => {
            const fumToBurn = priceWAD.mul(new BN('3')).div(new BN('4'))
            await expectRevert(
              proxy.defund(user1, user1, fumToBurn, MAX, { from: user1 }), // defund 75% of our fum
              "Limit not reached",
            )
          })

          it('allows burning USM', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()
            const startingBalance = await weth.balanceOf(user1)

            await proxy.burn(user1, user1, usmBalance, 0, { from: user1 })
            const newUsmBalance = (await usm.balanceOf(user1))
            newUsmBalance.toString().should.equal('0')

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()

            await expectRevert(
              proxy.burn(user1, user1, usmBalance, MAX, { from: user1 }),
              "Limit not reached",
            )
          })
        })
      })
    })
  })
})
