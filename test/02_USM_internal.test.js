const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const TestOracle = artifacts.require('./TestOracle.sol')
const MockUSM = artifacts.require('./MockUSM.sol')

const EVM_REVERT = 'VM Exception while processing transaction: revert'

require('chai').use(require('chai-as-promised')).should()

contract('USM - Internal functions', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  let mockToken

  const price = new BN('25000000000')
  const shift = new BN('8')
  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const priceWAD = WAD.mul(price).div(new BN('10').pow(shift))

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
    mockToken = await MockUSM.new(oracle.address, { from: deployer })
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

    it('returns the value of eth in usm', async () => {
      const oneEth = WAD
      const equivalentUSM = oneEth.mul(priceWAD).div(WAD)
      let usmAmount = (await mockToken.ethToUsm(oneEth)).toString()
      usmAmount.should.equal(equivalentUSM.toString())
    })

    it('returns the value of usm in eth', async () => {
      const oneUSM = WAD
      const equivalentEth = oneUSM.mul(WAD).div(priceWAD)
      let ethAmount = (await mockToken.usmToEth(oneUSM.toString())).toString()
      ethAmount.should.equal(equivalentEth.toString())
    })

    it('returns the debt ratio as zero', async () => {
      const ZERO = new BN('0')
      let debtRatio = (await mockToken.debtRatio()).toString()
      debtRatio.should.equal(ZERO.toString())
    })
  })
})
