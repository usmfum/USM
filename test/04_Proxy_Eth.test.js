const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const WETH9 = artifacts.require('WETH9')
const TestOracle = artifacts.require('TestOracle')
const USM = artifacts.require('USM')
const FUM = artifacts.require('FUM')
const USMView = artifacts.require('USMView')
const Proxy = artifacts.require('Proxy')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Eth', (accounts) => {
  const [deployer, user1, user2] = accounts
  const [TWO, WAD] =
        [2, '1000000000000000000'].map(function (n) { return new BN(n) })

  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const price = new BN(250)
  const priceWAD = price.mul(WAD)

  describe('mints and burns a static amount', () => {
    let weth, oracle, usm, fum, usmView, proxy

    beforeEach(async () => {
      // Deploy contracts
      weth = await WETH9.new({ from: deployer })
      oracle = await TestOracle.new(priceWAD, { from: deployer })
      usm = await USM.new(oracle.address, [], { from: deployer })
      await usm.refreshPrice()  // Ensures the savedPrice passed to the constructor above is also set in usm.storedPrice
      fum = await FUM.at(await usm.fum())
      usmView = await USMView.new(usm.address, { from: deployer })
      proxy = await Proxy.new(usm.address, weth.address, { from: deployer })

      await weth.deposit({ from: user1, value: oneEth.mul(TWO) }) // One 1-ETH fund() + one 1-ETH mint()
      await weth.approve(proxy.address, MAX, { from: user1 })
      await usm.addDelegate(proxy.address, { from: user1 })
      await usm.approve(user1, MAX, { from: user1 })
    })

    describe('minting and burning', () => {

      it('allows minting FUM', async () => {
        const startingEthPool = await usm.ethPool()
        const startingFumBalance = await fum.balanceOf(user1)

        await proxy.fund(user1, oneEth, 0, { from: user1 })

        const endingEthPool = await usm.ethPool()
        endingEthPool.should.be.bignumber.equal(startingEthPool.add(oneEth))
        const endingFumBalance = await fum.balanceOf(user1)
        endingFumBalance.should.be.bignumber.gt(startingFumBalance)
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          proxy.fund(user1, oneEth, MAX, { from: user1 }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(user1, oneEth, 0, { from: user1 })
        })

        it('allows minting USM', async () => {
          const startingEthPool = await usm.ethPool()
          const startingUsmBalance = await usm.balanceOf(user1)

          await proxy.mint(user1, oneEth, 0, { from: user1 })

          const endingEthPool = await usm.ethPool()
          endingEthPool.should.be.bignumber.equal(startingEthPool.add(oneEth))
          const endingUsmBalance = await usm.balanceOf(user1)
          endingUsmBalance.should.be.bignumber.gt(startingUsmBalance)
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            proxy.mint(user1, oneEth, MAX, { from: user1 }),
            "Limit not reached",
          )
        })

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mint(user1, oneEth, 0, { from: user1 })
          })

          it('allows minting USM by sending ETH, if no minUsmOut specified (1)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000000000' }) // Special case: all 0s = no flag
          })

          it('allows minting USM by sending ETH, if no minUsmOut specified (2)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000010000000' }) // 0001 spoils the flag
          })

          it('allows minting USM by sending ETH, if no minUsmOut specified (3)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000010000000000' }) // 1000 spoils the flag
          })

          it('allows minting USM by sending ETH, if no minUsmOut specified (4)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000100000000000' }) // Back to the all-0s special case
          })

          it('allows minting USM by sending ETH, if minUsmOut specified but met (1)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000000001' }) // Returns >= 0.01 USM per ETH
          })

          it('allows minting USM by sending ETH, if minUsmOut specified but met (2)', async () => {
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000010136' }) // Returns >= 101.36 USM per ETH
          })

          it('does not mint USM by sending ETH, if minUsmOut specified and missed (1)', async () => {
            await expectRevert(
              web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000010137' }), // Returns < 101.37 USM per ETH
              "Limit not reached",
            )
          })

          it('does not mint USM by sending ETH, if minUsmOut specified and missed (2)', async () => {
            await expectRevert(
              web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000001000000' }), // Returns < 10,000.00 USM per ETH
              "Limit not reached",
            )
          })

          it('allows burning USM by sending it, if no minEthOut specified', async () => {
            await usm.transfer(usm.address, '1000000000000000000', { from: user1 }) // Special case: all 0s = no flag
          })

          it('allows burning USM by sending it, if minEthOut specified but met', async () => {
            await usm.transfer(usm.address, '1000000000000017703', { from: user1 }) // Pays <= 177.03 USM per ETH
          })

          it('does not burn USM by sending it, if minEthOut specified and missed (1)', async () => {
            await expectRevert(
              usm.transfer(usm.address, '1000000000000017702', { from: user1 }), // Pays > 177.02 USM per ETH
              "Limit not reached",
            )
          })

          it('does not burn USM by sending it, if minEthOut specified and missed (2)', async () => {
            await expectRevert(
              usm.transfer(usm.address, '1000000000000000001', { from: user1 }), // Pays > 0.01 USM per ETH
              "Limit not reached",
            )
          })

          it('allows burning FUM', async () => {
            const startingFumBalance = await fum.balanceOf(user1)
            const startingEthPool = await usm.ethPool()
            const startingWethBalance = await weth.balanceOf(user1)

            const fumToBurn = startingFumBalance.mul(new BN('3')).div(new BN('4')) // defund 75% of our FUM
            await proxy.defund(user1, fumToBurn, 0, { from: user1 })

            const endingFumBalance = await fum.balanceOf(user1)
            endingFumBalance.should.be.bignumber.equal(startingFumBalance.sub(fumToBurn))
            const endingEthPool = await usm.ethPool()
            endingEthPool.should.be.bignumber.lt(startingEthPool)
            const endingWethBalance = await weth.balanceOf(user1)
            endingWethBalance.should.be.bignumber.equal(startingWethBalance.add(startingEthPool.sub(endingEthPool)))
          })

          it('does not burn FUM if minimum not reached', async () => {
            // Defunding the full balance would fail (violate MAX_DEBT_RATIO), so just defund half:
            const fumToBurn = (await fum.balanceOf(user1)).div(TWO)

            await expectRevert(
              proxy.defund(user1, fumToBurn, MAX, { from: user1 }),
              "Limit not reached",
            )
          })

          it('allows burning USM', async () => {
            const startingUsmBalance = await usm.balanceOf(user1)
            const startingEthPool = await usm.ethPool()
            const startingWethBalance = await weth.balanceOf(user1)

            const usmToBurn = startingUsmBalance // burn 100% of our USM
            await proxy.burn(user1, usmToBurn, 0, { from: user1 })

            const endingUsmBalance = await usm.balanceOf(user1)
            endingUsmBalance.should.be.bignumber.equal(startingUsmBalance.sub(usmToBurn))
            const endingEthPool = await usm.ethPool()
            endingEthPool.should.be.bignumber.lt(startingEthPool)
            const endingWethBalance = await weth.balanceOf(user1)
            endingWethBalance.should.be.bignumber.equal(startingWethBalance.add(startingEthPool.sub(endingEthPool)))
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmToBurn = await usm.balanceOf(user1)

            await expectRevert(
              proxy.burn(user1, usmToBurn, MAX, { from: user1 }),
              "Limit not reached",
            )
          })
        })
      })
    })
  })
})
