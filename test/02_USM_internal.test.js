const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('TestOracle')
const WETH9 = artifacts.require('WETH9')
const MockUSM = artifacts.require('MockUSM')

const EVM_REVERT = 'VM Exception while processing transaction: revert'

require('chai').use(require('chai-as-promised')).should()

contract('USM - Internal functions', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  let mockToken

  const price = new BN('25000')
  const shift = new BN('2')
  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const priceWAD = WAD.mul(price).div(new BN('10').pow(shift))

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
    weth = await WETH9.new({ from: deployer })
    mockToken = await MockUSM.new(oracle.address, weth.address, { from: deployer })
  })

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice()).toString()
      oraclePrice.should.equal(price.toString())
    })

    it('returns the correct decimal shift', async () => {
      let decimalshift = (await oracle.decimalShift()).toString()
      decimalshift.should.equal(shift.toString())
    })
  })

  describe('functionality', async () => {
    it('returns the oracle price in WAD', async () => {
      let oraclePrice = (await mockToken.oraclePrice()).toString()
      oraclePrice.should.equal(priceWAD.toString())
    })

    it('returns the value of weth in usm', async () => {
      const oneWeth = WAD
      const equivalentUSM = oneWeth.mul(priceWAD).div(WAD)
      let usmAmount = (await mockToken.wethToUsm(oneWeth)).toString()
      usmAmount.should.equal(equivalentUSM.toString())
    })

    it('returns the value of usm in weth', async () => {
      const oneUSM = WAD
      const equivalentWeth = oneUSM.mul(WAD).div(priceWAD)
      let wethAmount = (await mockToken.usmToWeth(oneUSM.toString())).toString()
      wethAmount.should.equal(equivalentWeth.toString())
    })

    it('returns the debt ratio as zero', async () => {
      const ZERO = new BN('0')
      let debtRatio = (await mockToken.debtRatio()).toString()
      debtRatio.should.equal(ZERO.toString())
    })
  })
})
