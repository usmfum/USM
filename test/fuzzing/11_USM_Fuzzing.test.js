const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const timeMachine = require('ganache-time-traveler')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')
const FUM = artifacts.require('./FUM.sol')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  function wadMul(x, y) {
    return x.mul(y).div(WAD);
  }

  function wadSquared(x) {
    return x.mul(x).div(WAD);
  }

  function wadDiv(x, y) {
    return x.mul(WAD).div(y);
  }

  function wadDecay(adjustment, decayFactor) {
    return WAD.add(wadMul(adjustment, decayFactor)).sub(decayFactor)
  }

  function shouldEqual(x, y) {
    x.toString().should.equal(y.toString())
  }

  function shouldEqualApprox(x, y, precision) {
    x.sub(y).abs().should.be.bignumber.lte(precision)
  }

  const [deployer, user1, user2, user3] = accounts

  const [ONE, TWO, THREE, FOUR, EIGHT, TEN, HUNDRED, THOUSAND] =
        [1, 2, 3, 4, 8, 10, 100, 1000].map(function (n) { return new BN(n) })
  const WAD = new BN('1000000000000000000')

  const sides = { BUY: 0, SELL: 1 }
  const price = new BN('25000000000')
  const shift = EIGHT
  const oneEth = WAD
  const oneUsm = WAD
  const oneFum = WAD
  const MINUTE = 60
  const HOUR = 60 * MINUTE
  const DAY = 24 * HOUR
  const priceWAD = wadDiv(price, TEN.pow(shift))

  describe("Fuzzing debugging helper", () => {
    let oracle, weth, usm

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })
      fum = await FUM.at(await usm.fum())

      let snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']
    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe("minting and burning", () => {
      it("fund and defund round trip", async () => {
        const ethIns = ['200790178637337', '100000000000001']
        for (let ethIn of ethIns) {
          console.log('')
          console.log(`          > ethIn:  ${ethIn}`)

          await weth.deposit({ from: user1, value: ethIn })
          await weth.approve(usm.address, ethIn, { from: user1 })
    
          const fumOut = await usm.fund.call(user1, user1, ethIn, { from: user1 })
          await usm.fund(user1, user1, ethIn, { from: user1 })
          console.log(`          > fumOut: ${fumOut}`)

          const ethOut = await usm.defund.call(user1, user1, fumOut, { from: user1 })
          await usm.defund(user1, user1, fumOut, { from: user1 })
          console.log(`          > ethOut: ${ethOut}`)
        }
      })
    })
  })
})