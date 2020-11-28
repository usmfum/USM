const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')
const timeMachine = require('ganache-time-traveler')

const USM = artifacts.require('MockTestOracleUSM')
const FUM = artifacts.require('FUM')
const FUMLimitOrderBook = artifacts.require('FUMLimitOrderBook')

require('chai').use(require('chai-as-promised')).should()

contract('USM', (accounts) => {
  const [deployer, user1, user2] = accounts
  const [ONE, TWO, FOUR, WAD] =
        [1, 2, 4, '1000000000000000000'].map(function (n) { return new BN(n) })
  const MAX = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  const sides = { BUY: 0, SELL: 1 }
  const rounds = { DOWN: 0, UP: 1 }
  const oneEth = WAD

  const price = new BN(250)
  const priceWAD = price.mul(WAD)
  let oneDollarInEth

  function wadDiv(x, y, upOrDown) {
    return ((x.mul(WAD)).add(y.sub(ONE))).div(y)
  }

  function shouldEqual(x, y) {
    x.toString().should.equal(y.toString())
  }

  function shouldEqualApprox(x, y) {
    // Check that abs(x - y) < 0.0000001(x + y):
    const diff = (x.gt(y) ? x.sub(y) : y.sub(x))
    diff.should.be.bignumber.lt(x.add(y).div(new BN(1000000)))
  }

  describe("mints and burns a static amount", () => {
    let usm, fum, orderBook, ethPerFund, ethPerMint, bidSize, bidPrices, snapshot, snapshotId

    beforeEach(async () => {
      // USM
      usm = await USM.new(priceWAD, { from: deployer })
      fum = await FUM.at(await usm.fum())
      orderBook = await FUMLimitOrderBook.new(usm.address)

      oneDollarInEth = wadDiv(WAD, priceWAD, rounds.UP)

      ethPerFund = oneEth.mul(TWO)                  // Can be any (?) number
      ethPerMint = oneEth.mul(FOUR)                 // Can be any (?) number
      bidSize = oneEth.div(new BN(10))
      bidPrices = [7, 100, 3, 10, 8, 9, 4, 15, 2, 3, 100, 200, 900, 70, 5]

      snapshot = await timeMachine.takeSnapshot()
      snapshotId = snapshot['result']
    })

    afterEach(async () => {
      await timeMachine.revertToSnapshot(snapshotId)
    })

    describe("deployment", () => {
      it("starts with correct FUM price", async () => {
        const fumBuyPrice = await usm.fumPrice(sides.BUY)
        // The FUM price should start off equal to $1, in ETH terms = 1 / price:
        shouldEqualApprox(fumBuyPrice, oneDollarInEth)

        const fumSellPrice = await usm.fumPrice(sides.SELL)
        shouldEqualApprox(fumSellPrice, oneDollarInEth)
      })
    })

    describe("with existing FUM and USM supply", () => {
      beforeEach(async () => {
        await usm.fund(user2, 0, { from: user1, value: ethPerFund })
        await usm.mint(user1, 0, { from: user2, value: ethPerMint })
      })

      it("allows limit orders", async () => {
        for (let j = -1; j < bidPrices.length; ++j) {
          if (j >= 0) { // So we print the heap both at the start and at the end of the operations loop
            console.log("Submitting " + bidPrices[j] + "...")
            await orderBook.submitBid(WAD.mul(new BN(bidPrices[j])).div(new BN(1000)), { from: user1, value: bidSize })
            console.log("Submitted.")
          }

          // I wish I knew how to move shared web3 test code like this heap logging into a shared function, but I don't
          const ethBal = await web3.eth.getBalance(orderBook.address)
          const fumBal = await fum.totalSupply()
          console.log(ethBal + " ETH, " + fumBal + " FUM.  Heap:")
          const heapSize = await orderBook.bidHeapSize()
          for (let i = 1; i <= heapSize; ++i) {
            const orderNum = await orderBook.getOrderNumber(new BN(i))
            if (orderNum != 0) {
              const {sender, qty, price, heapIndex} = await orderBook.getBidDetails(orderNum)
              shouldEqual(heapIndex, i)
              console.log("    " + i + ": bid #" + orderNum + ":\t" + qty + " ETH @ " + price + " ETH per FUM")
            }
          }
        }
      })

      describe("with existing limit orders", () => {
        beforeEach(async () => {
          for (let j = 0; j < bidPrices.length; ++j) {
            await orderBook.submitBid(WAD.mul(new BN(bidPrices[j])).div(new BN(1000)), { from: user1, value: bidSize })
          }
        })

        it("allows canceling orders", async () => {
          let orderNums = [3, 13, 12, 5, 8, 4, 10, 2, 1, 9, 11, 7]
          for (let j = -1; j < orderNums.length; ++j) {
            if (j >= 0) { // So we print the heap both at the start and at the end of the operations loop
              console.log("Canceling " + orderNums[j] + "...")
              await orderBook.cancelBid(new BN(orderNums[j]), { from: user1 })
              console.log("Canceled.")
            }

            const ethBal = await web3.eth.getBalance(orderBook.address)
            const fumBal = await fum.totalSupply()
            console.log(ethBal + " ETH, " + fumBal + " FUM.  Heap:")
            const heapSize = await orderBook.bidHeapSize()
            for (let i = 1; i <= heapSize; ++i) {
              const orderNum = await orderBook.getOrderNumber(new BN(i))
              if (orderNum != 0) {
                const {sender, qty, price, heapIndex} = await orderBook.getBidDetails(orderNum)
                shouldEqual(heapIndex, i)
                console.log("    " + i + ": bid #" + orderNum + ":\t" + qty + " ETH @ " + price + " ETH per FUM")
              }
            }
          }
        })

        it("doesn't allow canceling someone else's order", async () => {
          orderBook.cancelBid(new BN(11), { from: user1 })
          await expectRevert(orderBook.cancelBid(new BN(12), { from: user2 }), "Only creator can cancel")
        })

        it("allows executing orders", async () => {
          orderNums = [13, 11, 14, 1]
          for (let j = -1; j < orderNums.length; ++j) {
            if (j >= 0) { // So we print the heap both at the start and at the end of the operations loop
              console.log("Executing " + orderNums[j] + "...")
              await orderBook.executeBid(new BN(orderNums[j]), { from: user1 })
              console.log("Executed.")
            }

            const ethBal = await web3.eth.getBalance(orderBook.address)
            const fumBal = await fum.totalSupply()
            console.log(ethBal + " ETH, " + fumBal + " FUM.  Heap:")
            const heapSize = await orderBook.bidHeapSize()
            for (let i = 1; i <= heapSize; ++i) {
              const orderNum = await orderBook.getOrderNumber(new BN(i))
              if (orderNum != 0) {
                const {sender, qty, price, heapIndex} = await orderBook.getBidDetails(orderNum)
                shouldEqual(heapIndex, i)
                console.log("    " + i + ": bid #" + orderNum + ":\t" + qty + " ETH @ " + price + " ETH per FUM")
              }
            }
          }
        })

        it("doesn't allow executing nonexistent orders", async () => {
          await expectRevert(orderBook.executeBid(new BN(123), { from: user1 }), "Bid doesn't exist")
        })

        it("fails to execute order with too-low maxFumPriceInEth", async () => {
          orderNums = [13, 11, 14, 1]
          for (let j = 0; j < orderNums.length; ++j) {
            await orderBook.executeBid(new BN(orderNums[j]), { from: user1 })
          }
          await expectRevert(orderBook.executeBid(new BN(3), { from: user1 }), "Limit not reached")
        })
      })
    })
  })
})
