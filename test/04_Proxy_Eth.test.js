const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')
const Proxy = artifacts.require('Proxy')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Eth', (accounts) => {
  function wadMul(x, y) {
    return ((x.mul(y)).add(WAD.div(TWO))).div(WAD)
  }

  function wadSquared(x) {
    return wadMul(x, x)
  }

  function wadCubed(x) {
    return wadMul(wadMul(x, x), x)
  }

  function wadDiv(x, y) {
    return ((x.mul(WAD)).add(y.div(TWO))).div(y)
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = (x.gt(y) ? x.sub(y) : y.sub(x))
    diff.should.be.bignumber.lt(x.add(y).div(new BN(1000000)))
  }

  const [deployer, user1, user2] = accounts

  const [ZERO, ONE, TWO, THREE, EIGHT, TEN] =
        [0, 1, 2, 3, 8, 10].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')
  const WAD_SQUARED = WAD.mul(WAD)

  const sides = { BUY: 0, SELL: 1 }
  const ethTypes = { ETH: 0, WETH: 1 }
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
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

      await usm.addDelegate(proxy.address, { from: user1 })
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
            const integralFirstPart = wadMul(fumToBurn, fumSellPrice)
            const targetEthOut = wadDiv(wadMul(ethPool, integralFirstPart), ethPool.add(integralFirstPart))
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
            const integralFirstPart = ethPool.sub(wadMul(wadMul(usmSellPrice, usmBalance),
                                                         WAD.sub(wadCubed(wadDiv(usmBalance2, usmBalance)))))
            const targetEthPool2Cubed = wadMul(wadSquared(ethPool), integralFirstPart)
            const ethPool2Cubed = wadCubed(ethPool.sub(ethOut))
            shouldEqualApprox(ethPool2Cubed, targetEthPool2Cubed)
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
