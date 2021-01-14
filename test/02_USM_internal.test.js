const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const USM = artifacts.require('MockTestOracleUSM')

const EVM_REVERT = 'VM Exception while processing transaction: revert'

require('chai').use(require('chai-as-promised')).should()

contract('USM - Internal functions', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  let usm
  const rounds = { DOWN: 0, UP: 1 }

  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const price = new BN('250')
  const priceWAD = price.mul(WAD)

  beforeEach(async () => {
    usm = await USM.new(priceWAD, { from: deployer })
    await usm.refreshPrice()    // Ensures the savedPrice set in TestOracle is also set in usm.storedPrice
  })

  describe('functionality', async () => {
    it('returns the oracle price in WAD', async () => {
      const oraclePrice = (await usm.latestPrice())[0]
      oraclePrice.toString().should.equal(priceWAD.toString())
    })

    it('returns the value of eth in usm', async () => {
      const oneEth = WAD
      const equivalentUSM = oneEth.mul(priceWAD).div(WAD)
      const usmAmount = await usm.ethToUsm(oneEth, rounds.DOWN)
      usmAmount.toString().should.equal(equivalentUSM.toString())
    })

    it('returns the value of usm in eth', async () => {
      const oneUsm = WAD
      const equivalentEth = oneUsm.mul(WAD).div(priceWAD)
      const ethAmount = await usm.usmToEth(oneUsm, rounds.DOWN)
      ethAmount.toString().should.equal(equivalentEth.toString())
    })

    it('returns the debt ratio as zero', async () => {
      const ZERO = new BN('0')
      const debtRatio = (await usm.debtRatio())
      debtRatio.toString().should.equal(ZERO.toString())
    })
  })
})
