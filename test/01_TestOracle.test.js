const TestOracle = artifacts.require('./TestOracle.sol')

require('chai').use(require('chai-as-promised')).should()

contract('TestOracle', (accounts) => {
  const [deployer] = accounts
  let oracle

  const price = '25000'
  const shift = '8'

  beforeEach(async () => {
    oracle = await TestOracle.new(price, shift, { from: deployer })
  })

  describe('deployment', async () => {
    it('returns the correct price', async () => {
      let oraclePrice = (await oracle.latestPrice())
      oraclePrice.toString().should.equal(price)
    })

    it('returns the correct decimal shift', async () => {
      let oracleShift = (await oracle.decimalShift())
      oracleShift.toString().should.equal(shift)
    })
  })
})
