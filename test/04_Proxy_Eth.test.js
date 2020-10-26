const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')
const Proxy = artifacts.require('./Proxy.sol')

const burnSignature = id('burn(address,address,uint256)').slice(0, 10)
const defundSignature = id('defund(address,address,uint256)').slice(0, 10)

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Eth', (accounts) => {
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

  const [deployer, user1, user2] = accounts

  const [ZERO, ONE, TWO, THREE, EIGHT, TEN] =
        [0, 1, 2, 3, 8, 10].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const ethTypes = { ETH: 0, WETH: 1 }
  const price = new BN('25000000000')
  const shift = EIGHT
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const priceWAD = wadDiv(price, TEN.pow(shift))

  describe('mints and burns a static amount', () => {
    let oracle, weth, usm, proxy

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })
      fum = await FUM.at(await usm.fum())
      proxy = await Proxy.new(usm.address, weth.address, { from: deployer })

      await usm.addDelegate(proxy.address, burnSignature, MAX, { from: user1 })
      await usm.addDelegate(proxy.address, defundSignature, MAX, { from: user1 })
    })

    describe('minting and burning', () => {

      // See 03_USM.test.js for the original versions of all these (copy-&-pasted and simplified) tests.
      it('allows minting FUM', async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumBuyPrice.toString().should.equal(fumSellPrice.toString())

        await proxy.fund(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
        const ethPool2 = (await weth.balanceOf(usm.address))
        ethPool2.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          proxy.fund(oneEth, MAX, ethTypes.ETH, { from: user1, value: oneEth }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
        })

        it('allows minting USM', async () => {
          await proxy.mint(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
          const ethPool2 = (await weth.balanceOf(usm.address))
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = (await usm.balanceOf(user1))
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD).toString()) // Just qty * price, no sliding prices yet
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            proxy.mint(oneEth, MAX, ethTypes.ETH, { from: user1, value: oneEth }),
            "Limit not reached",
          )
        })  

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mint(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
          })

          it('allows burning FUM', async () => {
            const ethPool = (await usm.ethPool())
            const debtRatio = (await usm.debtRatio())
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const fumBalance = (await fum.balanceOf(user1))
            const ethBalance = new BN(await web3.eth.getBalance(user1))
            const targetFumBalance = wadMul(oneEth, priceWAD) // see "allows minting FUM" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const fumToBurn = priceWAD.div(TWO)
            await proxy.defund(fumToBurn, 0, ethTypes.ETH, { from: user1, gasPrice: 0 }) // Don't use eth on gas
            const fumBalance2 = (await fum.balanceOf(user1))
            fumBalance2.toString().should.equal(fumBalance.sub(fumToBurn).toString())

            const ethBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = ethBalance2.sub(ethBalance)
            // Like most of this file, this math is cribbed from 03_USM.test.js (originally, from USM.sol, eg ethFromDefund()):
            const integralFirstPart = wadMul(wadSquared(fumBalance).sub(wadSquared(fumBalance2)), wadSquared(fumSellPrice))
            const targetEthPool2 = wadSqrt(wadSquared(ethPool).sub(wadDiv(integralFirstPart, debtRatio)))
            const targetEthOut = ethPool.sub(targetEthPool2)
            ethOut.toString().should.equal(targetEthOut.toString())
          })

          it('does not burn FUM if minimum not reached', async () => {
            const fumBalance = (await fum.balanceOf(user1))

            await expectRevert(
              // Defunding the full balance would fail (violate MAX_DEBT_RATIO), so just defund half:
              proxy.defund(fumBalance.div(TWO), MAX, ethTypes.ETH, { from: user1 }),
              "Limit not reached",
            )
          })    

          it('allows burning USM', async () => {
            const ethPool = (await usm.ethPool())
            const debtRatio = (await usm.debtRatio())
            const usmSellPrice = (await usm.usmPrice(sides.SELL))

            const usmBalance = (await usm.balanceOf(user1))
            const ethBalance = new BN(await web3.eth.getBalance(user1))

            const usmToBurn = usmBalance
            await proxy.burn(usmToBurn, 0, ethTypes.ETH, { from: user1, gasPrice: 0})
            const usmBalance2 = (await usm.balanceOf(user1))
            usmBalance2.toString().should.equal('0')

            const ethBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = ethBalance2.sub(ethBalance)
            const integralFirstPart = wadMul(wadSquared(usmBalance).sub(wadSquared(usmBalance2)), wadSquared(usmSellPrice))
            const targetEthPool2 = wadSqrt(wadSquared(ethPool).sub(wadDiv(integralFirstPart, debtRatio)))
            const targetEthOut = ethPool.sub(targetEthPool2)
            ethOut.toString().should.equal(targetEthOut.toString())
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1))

            await expectRevert(
              proxy.burn(usmBalance, MAX, ethTypes.ETH, { from: user1 }),
              "Limit not reached",
            )
          })    
        })
      })
    })
  })
})
