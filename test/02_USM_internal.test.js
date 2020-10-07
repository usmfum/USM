const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')
const MockUSM = artifacts.require('MockUSM')
const WETH9 = artifacts.require('WETH9')

const EVM_REVERT = 'VM Exception while processing transaction: revert'

require('chai').use(require('chai-as-promised')).should()

contract('USM - Internal functions', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  let usm

  const price = new BN('25000000000')
  const shift = new BN('8')
  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const priceWAD = WAD.mul(price).div(new BN('10').pow(shift))

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
    weth = await WETH9.new({ from: deployer })
    usm = await MockUSM.new(oracle.address, weth.address, { from: deployer })
  })

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = await oracle.latestPrice()
      oraclePrice.toString().should.equal(price.toString())
    })

    it('returns the correct decimal shift', async () => {
      let decimalshift = await oracle.decimalShift()
      decimalshift.toString().should.equal(shift.toString())
    })
  })

  describe('functionality', async () => {
    it('returns the oracle price in WAD', async () => {
      let oraclePrice = await usm.oraclePrice()
      oraclePrice.toString().should.equal(priceWAD.toString())
    })

    it('returns the value of eth in usm', async () => {
      const oneEth = WAD
      const equivalentUSM = oneEth.mul(priceWAD).div(WAD)
      let usmAmount = await usm.ethToUsm(oneEth)
      usmAmount.toString().should.equal(equivalentUSM.toString())
    })

    it('returns the value of usm in eth', async () => {
      const oneUSM = WAD
      const equivalentEth = oneUSM.mul(WAD).div(priceWAD)
      let ethAmount = await usm.usmToEth(oneUSM.toString())
      ethAmount.toString().should.equal(equivalentEth.toString())
    })

    it('returns the debt ratio as MAX_DEBT_RATIO', async () => {
      const MAX_DEBT_RATIO = await usm.MAX_DEBT_RATIO()
      let debtRatio = (await usm.debtRatio())
      debtRatio.toString().should.equal(MAX_DEBT_RATIO.toString())
    })
  })
})
