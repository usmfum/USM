const { BN, expectRevert } = require('@openzeppelin/test-helpers')

const USM = artifacts.require('MockTestOracleUSM')
const WETH9 = artifacts.require('WETH9')

const EVM_REVERT = 'VM Exception while processing transaction: revert'

require('chai').use(require('chai-as-promised')).should()

contract('USM - Internal functions', (accounts) => {
  const [deployer, user1, user2, user3] = accounts
  let usm

  const ZERO = new BN('0')
  const WAD = new BN('1000000000000000000')
  const price = new BN('250')
  const priceWAD = price.mul(WAD)

  beforeEach(async () => {
    weth = await WETH9.new({ from: deployer })
    usm = await USM.new(weth.address, priceWAD, { from: deployer })
  })

  describe('functionality', async () => {
    it('returns the oracle price in WAD', async () => {
      const oraclePrice = await usm.latestPrice()
      oraclePrice.toString().should.equal(priceWAD.toString())
    })

    it('returns the value of eth in usm', async () => {
      const oneEth = WAD
      const equivalentUSM = oneEth.mul(priceWAD).div(WAD)
      const usmAmount = await usm.ethToUsm(oneEth)
      usmAmount.toString().should.equal(equivalentUSM.toString())
    })

    it('returns the value of usm in eth', async () => {
      const oneUsm = WAD
      const equivalentEth = oneUsm.mul(WAD).div(priceWAD)
      const ethAmount = await usm.usmToEth(oneUsm)
      ethAmount.toString().should.equal(equivalentEth.toString())
    })

    it('returns the debt ratio as zero', async () => {
      const ZERO = new BN('0')
      const debtRatio = (await usm.debtRatio())
      debtRatio.toString().should.equal(ZERO.toString())
    })
  })
})
