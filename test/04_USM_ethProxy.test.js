const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { expect } = require('chai')
const { id } = require('ethers/lib/utils')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')
const EthProxy = artifacts.require('./EthProxy.sol')

const burnSignature = id('burn(address,address,uint256)').slice(0, 10)
const defundSignature = id('defund(address,address,uint256)').slice(0, 10)
MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'

require('chai').use(require('chai-as-promised')).should()

contract('USM - EthProxy', (accounts) => {
  function wadMul(x, y) {
    return x.mul(y).div(WAD);
  }

  function wadDiv(x, y) {
    return x.mul(WAD).div(y);
  }

  const [deployer, user1, user2] = accounts

  const [TWO, EIGHT, TEN] =
        [2, 8, 10].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = EIGHT
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
      proxy = await EthProxy.new(usm.address, weth.address, { from: deployer })

      await usm.addDelegate(proxy.address, burnSignature, MAX, { from: user1 })
      await usm.addDelegate(proxy.address, defundSignature, MAX, { from: user1 })
    })

    describe('minting and burning', () => {

      // See 03_USM.test.js for the original versions of all these (copy-&-pasted and simplified) tests.
      it('allows minting FUM', async () => {
        const fumBuyPrice = (await usm.fumPrice(sides.BUY))
        const fumSellPrice = (await usm.fumPrice(sides.SELL))
        fumBuyPrice.toString().should.equal(fumSellPrice.toString())

        await proxy.fund(user2, { from: user1, value: oneEth })
        const ethPool2 = (await weth.balanceOf(usm.address))
        ethPool2.toString().should.equal(oneEth.toString())
      })

      describe('with existing FUM supply', () => {
        beforeEach(async () => {
          await proxy.fund(user1, { from: user1, value: oneEth })
        })

        it('allows minting USM', async () => {
          await proxy.mint(user2, { from: user1, value: oneEth })
          const ethPool2 = (await weth.balanceOf(usm.address))
          ethPool2.toString().should.equal(oneEth.mul(TWO).toString())

          const usmBalance2 = (await usm.balanceOf(user2))
          usmBalance2.toString().should.equal(wadMul(oneEth, priceWAD).div(TWO).toString())
        })

        describe('with existing USM supply', () => {
          beforeEach(async () => {
            await proxy.mint(user1, { from: user1, value: oneEth })
          })

          it('allows burning FUM', async () => {
            const ethPool = (await usm.ethPool())
            const fumSellPrice = (await usm.fumPrice(sides.SELL))

            const user1FumBalance = (await fum.balanceOf(user1))
            const user2EthBalance = new BN(await web3.eth.getBalance(user2))
            const targetUser1FumBalance = wadMul(oneEth, priceWAD) // see "allows minting FUM" above
            user1FumBalance.toString().should.equal(targetUser1FumBalance.toString())

            const fumToBurn = priceWAD.div(TWO)
            await proxy.defund(user2, fumToBurn, { from: user1 })
            const user1FumBalance2 = (await fum.balanceOf(user1))
            user1FumBalance2.toString().should.equal(user1FumBalance.sub(fumToBurn).toString())

            const user2EthBalance2 = new BN(await web3.eth.getBalance(user2))
            const ethOut = user2EthBalance2.sub(user2EthBalance)
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(fumToBurn, fumSellPrice))))
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())
          })

          it('allows burning USM', async () => {
            const ethPool = (await usm.ethPool())
            const usmSellPrice = (await usm.usmPrice(sides.SELL))

            const user2EthBalance = new BN(await web3.eth.getBalance(user2))

            const usmToBurn = (await usm.balanceOf(user1))
            await proxy.burn(user2, usmToBurn, { from: user1 })
            const user1UsmBalance2 = (await usm.balanceOf(user1))
            user1UsmBalance2.toString().should.equal('0')

            const user2EthBalance2 = new BN(await web3.eth.getBalance(user2))
            const ethOut = user2EthBalance2.sub(user2EthBalance)
            const targetEthOut = wadDiv(WAD, wadDiv(WAD, ethPool).add(wadDiv(WAD, wadMul(usmToBurn, usmSellPrice))))
            ethOut.divRound(TEN).toString().should.equal(targetEthOut.divRound(TEN).toString())
          })
        })
      })
    })
  })
})
