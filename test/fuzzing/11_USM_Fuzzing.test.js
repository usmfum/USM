const { BN } = require('@openzeppelin/test-helpers')
const timeMachine = require('ganache-time-traveler')

const TestOracle = artifacts.require('./TestOracle.sol')
const WETH9 = artifacts.require('WETH9')
const USM = artifacts.require('./USM.sol')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  const [deployer, user1] = accounts

  const price = new BN('25000000000')
  const shift = new BN(8)

  describe('Fuzzing debugging helper', () => {
    let oracle, weth, usm, snapshotId

    beforeEach(async () => {
      // Deploy contracts
      oracle = await TestOracle.new(price, shift, { from: deployer })
      weth = await WETH9.new({ from: deployer })
      usm = await USM.new(oracle.address, weth.address, { from: deployer })

      let snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']
    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe('minting and burning', () => {
      it('fund and defund round trip', async () => {
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
