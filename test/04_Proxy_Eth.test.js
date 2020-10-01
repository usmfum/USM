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
    return x.mul(y).div(WAD);
  }

  function wadDiv(x, y) {
    return x.mul(WAD).div(y);
  }

  const [deployer, user1, user2] = accounts

  const [ZERO, TWO, EIGHT, TEN] =
        [0, 2, 8, 10].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
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

        await proxy.fundWithEth(0, { from: user1, value: oneEth })
        const ethPool2 = (await weth.balanceOf(usm.address))
        ethPool2.toString().should.equal(oneEth.toString())
      })

      it('does not mint FUM if minimum not reached', async () => {
        await expectRevert(
          proxy.fundWithEth(MAX, { from: user1, value: oneEth }),
          "Limit not reached",
        )
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fundWithEth(0, { from: user1, value: oneEth })
        })

        it('allows minting USM', async () => {
          await proxy.mintWithEth(0, { from: user1, value: oneEth })
          const ethPool2 = (await weth.balanceOf(usm.address))
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = (await usm.balanceOf(user1))
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD).div(TWO).toString())
        })

        it('does not mint USM if minimum not reached', async () => {
          await expectRevert(
            proxy.mintWithEth(MAX, { from: user1, value: oneEth }),
            "Limit not reached",
          )
        })  

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mintWithEth(0, { from: user1, value: oneEth })
          })

          it('allows burning FUM', async () => {
            const ethPool = (await usm.ethPool())
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const userFumBalance = (await fum.balanceOf(user1))
            const userEthBalance = new BN(await web3.eth.getBalance(user1))
            const targetUserFumBalance = wadMul(oneEth, priceWAD) // see "allows minting FUM" above
            userFumBalance.toString().should.equal(targetUserFumBalance.toString())

            const fumToBurn = priceWAD.div(TWO)
            await proxy.defundForEth(fumToBurn, 0, { from: user1, gasPrice: 0 }) // Don't use eth on gas
            const userFumBalance2 = (await fum.balanceOf(user1))
            userFumBalance2.toString().should.equal(userFumBalance.sub(fumToBurn).toString())

            const userEthBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = userEthBalance2.sub(userEthBalance)
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(fumToBurn, fumSellPrice))))
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())
          })

          it('does not burn FUM if minimum not reached', async () => {
            const fumBalance = (await fum.balanceOf(user1))

            await expectRevert(
              // Defunding the full balance would fail (violate MAX_DEBT_RATIO), so just defund half:
              proxy.defundForEth(fumBalance.div(TWO), MAX, { from: user1 }),
              "Limit not reached",
            )
          })    

          it('allows burning USM', async () => {
            const ethPool = (await usm.ethPool())
            const usmSellPrice = (await usm.usmPrice(sides.SELL))

            const userEthBalance = new BN(await web3.eth.getBalance(user1))

            const usmToBurn = (await usm.balanceOf(user1))
            await proxy.burnForEth(usmToBurn, 0, { from: user1, gasPrice: 0})
            const userUsmBalance2 = (await usm.balanceOf(user1))
            userUsmBalance2.toString().should.equal('0')

            const userEthBalance2 = new BN(await web3.eth.getBalance(user1))
            const ethOut = userEthBalance2.sub(userEthBalance)
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(usmToBurn, usmSellPrice))))
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())
          })

          it('does not burn USM if minimum not reached', async () => {
            const usmBalance = (await usm.balanceOf(user1))

            await expectRevert(
              proxy.burnForEth(usmBalance, MAX, { from: user1 }),
              "Limit not reached",
            )
          })    
        })
      })
    })
  })
})
