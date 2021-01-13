const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')
const Proxy = artifacts.require('Proxy')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Eth', (accounts) => {
  const [deployer, user1, user2] = accounts
  const [ZERO, ONE, TWO, THREE, EIGHT, TEN] = [0, 1, 2, 3, 8, 10].map(function (n) {
    return new BN(n)
  })
  const WAD = new BN('1000000000000000000')
  const WAD_MINUS_1 = WAD.sub(ONE)
  const WAD_SQUARED = WAD.mul(WAD)
  const WAD_SQUARED_MINUS_1 = WAD_SQUARED.sub(ONE)

  const sides = { BUY: 0, SELL: 1 }
  const rounds = { DOWN: 0, UP: 1 }
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const price = new BN(250)
  const priceWAD = price.mul(WAD)

  function wadMul(x, y, upOrDown) {
    return x
      .mul(y)
      .add(upOrDown == rounds.DOWN ? ZERO : WAD_MINUS_1)
      .div(WAD)
  }

  function wadSquared(x, upOrDown) {
    return wadMul(x, x, upOrDown)
  }

  function wadCubed(x, upOrDown) {
    return x
      .mul(x)
      .mul(x)
      .add(upOrDown == rounds.DOWN ? ZERO : WAD_SQUARED_MINUS_1)
      .div(WAD_SQUARED)
  }

  function wadDiv(x, y, upOrDown) {
    return x.mul(WAD).add(y.sub(ONE)).div(y)
  }

  function wadCbrt(y, upOrDown) {
    if (y.gt(ZERO)) {
      let root, newRoot
      newRoot = y.add(TWO.mul(WAD)).div(THREE)
      const yTimesWadSquared = y.mul(WAD_SQUARED)
      do {
        root = newRoot
        newRoot = root
          .add(root)
          .add(yTimesWadSquared.div(root.mul(root)))
          .div(THREE)
      } while (newRoot.lt(root))
      if (upOrDown == rounds.UP && root.pow(THREE).lt(y.mul(WAD_SQUARED))) {
        root = root.add(ONE)
      }
      return root
    }
    return ZERO
  }

  describe('mints and burns a static amount', () => {
    let weth, usm, proxy

    beforeEach(async () => {
      // Deploy contracts
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())
      proxy = await Proxy.new(usm.address, weth.address, { from: deployer })

      await weth.deposit({ from: user1, value: oneEth.mul(TWO) }) // One 1-ETH fund() + one 1-ETH mint()
      await weth.approve(proxy.address, MAX, { from: user1 })
      await usm.addDelegate(proxy.address, { from: user1 })
      await usm.approve(user1, MAX, { from: user1 })
    })

    describe('minting and burning', () => {
      // See 03_USM.test.js for the original versions of all these (copy-&-pasted and simplified) tests.
      it('allows minting FUM', async () => {
        const fumBuyPrice = await usm.fumPrice(sides.BUY)
        const fumSellPrice = await usm.fumPrice(sides.SELL)
        fumBuyPrice.toString().should.equal(fumSellPrice.toString())

        await proxy.fund(user1, oneEth, 0, { from: user1 })
        const ethPool2 = await usm.ethPool()
        ethPool2.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(proxy.fund(user1, oneEth, MAX, { from: user1 }), 'Limit not reached')
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(user1, oneEth, 0, { from: user1 })
        })

        it('allows minting USM', async () => {
          await proxy.mint(user1, oneEth, 0, { from: user1 })
          const ethPool2 = await usm.ethPool()
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = await usm.balanceOf(user1)
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD, rounds.DOWN).toString()) // Just qty * price, no sliding prices yet
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(proxy.mint(user1, oneEth, MAX, { from: user1 }), 'Limit not reached')
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
            await web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000019788' }) // Returns >= 197.88 USM per ETH
          })

          it('does not mint USM by sending ETH, if minUsmOut specified and missed (1)', async () => {
            await expectRevert(
              web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000000019789' }), // Returns < 197.89 USM per ETH
              'Limit not reached'
            )
          })

          it('does not mint USM by sending ETH, if minUsmOut specified and missed (2)', async () => {
            await expectRevert(
              web3.eth.sendTransaction({ from: user1, to: usm.address, value: '1000000000001000000' }), // Returns < 10,000.00 USM per ETH
              'Limit not reached'
            )
          })

          it('allows burning USM by sending it, if no minEthOut specified', async () => {
            await usm.transfer(usm.address, '1000000000000000000', { from: user1 }) // Special case: all 0s = no flag
          })

          it('allows burning USM by sending it, if minEthOut specified but met', async () => {
            await usm.transfer(usm.address, '1000000000000025051', { from: user1 }) // Pays <= 250.51 USM per ETH
          })

          it('does not burn USM by sending it, if minEthOut specified and missed (1)', async () => {
            await expectRevert(
              usm.transfer(usm.address, '1000000000000025050', { from: user1 }), // Pays > 250.50 USM per ETH
              'Limit not reached'
            )
          })

          it('does not burn USM by sending it, if minEthOut specified and missed (2)', async () => {
            await expectRevert(
              usm.transfer(usm.address, '1000000000000000001', { from: user1 }), // Pays > 0.01 USM per ETH
              'Limit not reached'
            )
          })

          it('allows burning FUM', async () => {
            const ethPool = await usm.ethPool()
            const debtRatio = await usm.debtRatio()
            const fumSellPrice = await usm.fumPrice(sides.SELL)

            const fumBalance = await fum.balanceOf(user1)
            const ethBalance = await weth.balanceOf(user1)
            const targetFumBalance = wadMul(oneEth, priceWAD, rounds.DOWN) // see "allows minting FUM" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const fumToBurn = priceWAD.div(TWO)
            await proxy.defund(user1, fumToBurn, 0, { from: user1, gasPrice: 0 }) // Don't use eth on gas
            const fumBalance2 = await fum.balanceOf(user1)
            fumBalance2.toString().should.equal(fumBalance.sub(fumToBurn).toString())

            const ethBalance2 = await weth.balanceOf(user1)
            const ethOut = ethBalance2.sub(ethBalance)
            // Like most of this file, this math is cribbed from 03_USM.test.js (originally, from USM.sol, eg ethFromDefund()):
            const targetEthOut = ethPool
              .mul(wadMul(fumToBurn, fumSellPrice, rounds.DOWN))
              .div(ethPool.add(wadMul(fumToBurn, fumSellPrice, rounds.UP)))
            ethOut.toString().should.equal(targetEthOut.toString())
          })

          it('does not burn FUM if minimum not reached', async () => {
            const fumBalance = await fum.balanceOf(user1)

            await expectRevert(
              // Defunding the full balance would fail (violate MAX_DEBT_RATIO), so just defund half:
              proxy.defund(user1, fumBalance.div(TWO), MAX, { from: user1 }),
              'Limit not reached'
            )
          })

          it('allows burning USM', async () => {
            const ethPool = await usm.ethPool()
            const debtRatio = await usm.debtRatio()
            const usmSellPrice = await usm.usmPrice(sides.SELL)

            const usmBalance = await usm.balanceOf(user1)
            const ethBalance = await weth.balanceOf(user1)

            const usmToBurn = usmBalance
            await proxy.burn(user1, usmToBurn, 0, { from: user1, gasPrice: 0 })
            const usmBalance2 = await usm.balanceOf(user1)
            usmBalance2.toString().should.equal('0')

            const ethBalance2 = await weth.balanceOf(user1)
            const ethOut = ethBalance2.sub(ethBalance)
            const ethPool2 = ethPool.sub(ethOut)
            const firstPart = wadMul(
              wadMul(usmSellPrice, usmBalance, rounds.DOWN),
              WAD.sub(wadCubed(wadDiv(usmBalance2, usmBalance, rounds.UP), rounds.UP)),
              rounds.DOWN
            )
            const targetEthPool2 = wadCbrt(
              wadMul(wadSquared(ethPool, rounds.UP), ethPool.sub(firstPart), rounds.UP),
              rounds.UP
            )
            ethPool2.toString().should.equal(targetEthPool2.toString())
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmToBurn = await usm.balanceOf(user1)

            await expectRevert(proxy.burn(user1, usmToBurn, MAX, { from: user1 }), 'Limit not reached')
          })
        })
      })
    })
  })
})
