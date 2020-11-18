const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')

require('chai').use(require('chai-as-promised')).should()

contract('USM - Proxy - Eth', (accounts) => {
  const [deployer, user1, user2] = accounts
  const [ZERO, ONE, TWO, THREE, EIGHT, TEN] =
        [0, 1, 2, 3, 8, 10].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')
  const WAD_MINUS_1 = WAD.sub(ONE)
  const WAD_SQUARED = WAD.mul(WAD)
  const WAD_SQUARED_MINUS_1 = WAD_SQUARED.sub(ONE)

  const sides = { BUY: 0, SELL: 1 }
  const rounds = { DOWN: 0, UP: 1 }
  const ethTypes = { ETH: 0, WETH: 1 }
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const oneEth = WAD
  const price = new BN(250)
  const priceWAD = price.mul(WAD)

  function wadMul(x, y, upOrDown) {
    return ((x.mul(y)).add(upOrDown == rounds.DOWN ? ZERO : WAD_MINUS_1)).div(WAD)
  }

  function wadSquared(x, upOrDown) {
    return wadMul(x, x, upOrDown)
  }

  function wadCubed(x, upOrDown) {
    return ((x.mul(x).mul(x)).add(upOrDown == rounds.DOWN ? ZERO : WAD_SQUARED_MINUS_1)).div(WAD_SQUARED)
  }

  function wadDiv(x, y, upOrDown) {
    return ((x.mul(WAD)).add(y.sub(ONE))).div(y)
  }

  function wadCbrt(y, upOrDown) {
    if (y.gt(ZERO)) {
      let root, newRoot
      newRoot = y.add(TWO.mul(WAD)).div(THREE)
      const yTimesWadSquared = y.mul(WAD_SQUARED)
      do {
        root = newRoot
        newRoot = root.add(root).add(yTimesWadSquared.div(root.mul(root))).div(THREE)
      } while (newRoot.lt(root))
      if ((upOrDown == rounds.UP) && root.pow(THREE).lt(y.mul(WAD_SQUARED))) {
        root = root.add(ONE)
      }
      return root
    }
    return ZERO
  }

  describe('mints and burns a static amount', () => {
    let weth, usm

    beforeEach(async () => {
      // Deploy contracts
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(weth.address, priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())

      // await usm.addDelegate(usm.address, { from: user1 })
    })

    describe('minting and burning', () => {

      // See 03_USM.test.js for the original versions of all these (copy-&-pasted and simplified) tests.
      it('allows minting FUM', async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumBuyPrice.toString().should.equal(fumSellPrice.toString())

        await usm.fundLimit(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
        const ethPool2 = (await weth.balanceOf(usm.address))
        ethPool2.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          usm.fundLimit(oneEth, MAX, ethTypes.ETH, { from: user1, value: oneEth }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await usm.fundLimit(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
        })

        it('allows minting USM', async () => {
          await usm.mintLimit(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
          const ethPool2 = (await weth.balanceOf(usm.address))
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = (await usm.balanceOf(user1))
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD, rounds.DOWN).toString()) // Just qty * price, no sliding prices yet
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            usm.mintLimit(oneEth, MAX, ethTypes.ETH, { from: user1, value: oneEth }),
            "Limit not reached",
          )
        })  

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await usm.mintLimit(oneEth, 0, ethTypes.ETH, { from: user1, value: oneEth })
          })

          it('allows burning FUM', async () => {
            const ethPool = (await usm.ethPool())
            const debtRatio = (await usm.debtRatio())
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const fumBalance = (await fum.balanceOf(user1))
            const ethBalance = new BN(await web3.eth.getBalance(user1))
            const targetFumBalance = wadMul(oneEth, priceWAD, rounds.DOWN) // see "allows minting FUM" above
            fumBalance.toString().should.equal(targetFumBalance.toString())

            const fumToBurn = priceWAD.div(TWO)
            await usm.defundLimit(fumToBurn, 0, ethTypes.ETH, { from: user1, gasPrice: 0 }) // Don't use eth on gas
            const fumBalance2 = (await fum.balanceOf(user1))
            fumBalance2.toString().should.equal(fumBalance.sub(fumToBurn).toString())

            const ethBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = ethBalance2.sub(ethBalance)
            // Like most of this file, this math is cribbed from 03_USM.test.js (originally, from USM.sol, eg ethFromDefund()):
            const targetEthOut = ethPool.mul(wadMul(fumToBurn, fumSellPrice, rounds.DOWN)).div(
                ethPool.add(wadMul(fumToBurn, fumSellPrice, rounds.UP)))
            ethOut.toString().should.equal(targetEthOut.toString())
          })

          it('does not burn FUM if minimum not reached', async () => {
            const fumBalance = (await fum.balanceOf(user1))

            await expectRevert(
              // Defunding the full balance would fail (violate MAX_DEBT_RATIO), so just defund half:
              usm.defundLimit(fumBalance.div(TWO), MAX, ethTypes.ETH, { from: user1 }),
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
            await usm.burnLimit(usmToBurn, 0, ethTypes.ETH, { from: user1, gasPrice: 0})
            const usmBalance2 = (await usm.balanceOf(user1))
            usmBalance2.toString().should.equal('0')

            const ethBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = ethBalance2.sub(ethBalance)
            const ethPool2 = ethPool.sub(ethOut)
            const firstPart = wadMul(wadMul(usmSellPrice, usmBalance, rounds.DOWN),
                                     WAD.sub(wadCubed(wadDiv(usmBalance2, usmBalance, rounds.UP), rounds.UP)), rounds.DOWN)
            const targetEthPool2 = wadCbrt(wadMul(wadSquared(ethPool, rounds.UP), ethPool.sub(firstPart), rounds.UP), rounds.UP)
            ethPool2.toString().should.equal(targetEthPool2.toString())
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1))

            await expectRevert(
              usm.burnLimit(usmBalance, MAX, ethTypes.ETH, { from: user1 }),
              "Limit not reached",
            )
          })    
        })
      })
    })
  })
})
