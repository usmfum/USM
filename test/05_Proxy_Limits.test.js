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
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const ethTypes = { ETH: 0, WETH: 1 }
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const oneUsm = WAD
  const price = new BN(250)
  const priceWAD = price.mul(WAD)

  describe('mints and burns a static amount', () => {
    let weth, usm, proxy

    beforeEach(async () => {
      // Deploy contracts
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(weth.address, priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())
      proxy = await Proxy.new(usm.address, weth.address, { from: deployer })

      await weth.deposit({ from: user1, value: oneEth.mul(new BN('2')) })
      await weth.approve(usm.address, MAX, { from: user1 })

      await usm.addDelegate(proxy.address, { from: user1 })
    })

    describe('minting and burning', () => {

      it('allows minting FUM', async () => {

        await proxy.fund(oneEth, 0, ethTypes.WETH, { from: user1 })

        const newEthPool = (await weth.balanceOf(usm.address))
        newEthPool.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          proxy.fund(oneEth, MAX, ethTypes.WETH, { from: user1 }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(oneEth, 0, ethTypes.WETH, { from: user1 })
        })

        it('allows minting USM', async () => {
          await proxy.mint(oneEth, 0, ethTypes.WETH, { from: user1 })
          const usmBalance = (await usm.balanceOf(user1))
          usmBalance.toString().should.equal(oneEth.mul(priceWAD).div(WAD).toString())
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            proxy.mint(oneEth, MAX, ethTypes.WETH, { from: user1 }),
            "Limit not reached",
          )
        })  

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mint(oneEth, 0, ethTypes.WETH, { from: user1 })
          })

          it('allows burning FUM', async () => {
            const targetFumBalance = oneEth.mul(priceWAD).div(WAD) // see "allows minting FUM" above
            const startingBalance = await weth.balanceOf(user1)

            await proxy.defund(priceWAD.mul(new BN('3')).div(new BN('4')), 0, ethTypes.WETH, { from: user1 }) // defund 75% of our fum
            const newFumBalance = (await fum.balanceOf(user1))
            newFumBalance.toString().should.equal(targetFumBalance.div(new BN('4')).toString()) // should be 25% of what it was

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn FUM if minimum not reached', async () => {
            await expectRevert(
              proxy.defund(priceWAD.mul(new BN('3')).div(new BN('4')), MAX, ethTypes.WETH, { from: user1 }),
              "Limit not reached",
            )
          })    

          it('allows burning USM', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()
            const startingBalance = await weth.balanceOf(user1)

            await proxy.burn(usmBalance, 0, ethTypes.WETH, { from: user1 })
            const newUsmBalance = (await usm.balanceOf(user1))
            newUsmBalance.toString().should.equal('0')

            expect(await weth.balanceOf(user1)).bignumber.gt(startingBalance)
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1)).toString()

            await expectRevert(
              proxy.burn(usmBalance, MAX, ethTypes.WETH, { from: user1 }),
              "Limit not reached",
            )
          })    
        })
      })
    })
  })
})
