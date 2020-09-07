const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const TestOracle = artifacts.require("./TestOracle.sol");
const MockBufferedToken = artifacts.require("./MockBufferedToken.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("BufferedToken", accounts => {
    const [deployer, user1, user2, user3] = accounts;
    let token;

    const price = new BN('25000');
    const shift = new BN('2');
    const ZERO = new BN('0');
    const WAD = new BN('1000000000000000000');
    const priceWAD = WAD.mul(price).div((new BN('10')).pow(shift));
    
    beforeEach(async() => {
        oracle = await TestOracle.new(price, shift, { from: deployer });
        token = await MockBufferedToken.new(oracle.address, "Name", "Symbol", { from: deployer });
    });

    describe("deployment", async () => {
        it("returns the correct price", async () => {
            let oraclePrice = (await oracle.latestPrice()).toString();
            oraclePrice.should.equal(price.toString());
        });

        it("returns the correct decimal shift", async () => {
            let decimalshift = (await oracle.decimalShift()).toString();
            decimalshift.should.equal(shift.toString());
        })
    });

    describe("functionality", async () => {
        it("returns the oracle price in WAD", async () => {
            let oraclePrice = (await token.oraclePrice()).toString();
            oraclePrice.should.equal(priceWAD.toString());
        })

        it("returns the value of eth in usm", async () => {
            const oneEth = WAD;
            const equivalentUSM = oneEth.mul(priceWAD).div(WAD);
            let usmAmount = (await token.ethToUsm(oneEth)).toString();
            usmAmount.should.equal(equivalentUSM.toString());
        })

        it("returns the value of usm in eth", async () => {
            const oneUSM = WAD;
            const equivalentEth = oneUSM.mul(WAD).div(priceWAD)
            let ethAmount = (await token.usmToEth(oneUSM)).toString();
            ethAmount.should.equal(equivalentEth.toString());
        })

        it("returns the debt ratio as zero", async () => {
            const ZERO = new BN('0');
            let debtRatio = (await token.debtRatio()).toString();
            debtRatio.should.equal(ZERO.toString());
        })

        it("allows minting", async () => {
            const oneEth = WAD;

            await token.mint(oneEth, { from: user1 });
            
            const tokenBalance = (await token.balanceOf(user1)).toString();
            tokenBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString());

            const ethPool = (await token.ethPool()).toString();
            ethPool.should.equal(oneEth.toString());
        })

        it("updates the debt ratio on mint", async () => {
            await token.mint(WAD, { from: user1 });
            let debtRatio = (await token.debtRatio()).toString();
            debtRatio.should.equal(WAD.toString());
        })

        describe("with a positive supply", async () => {
            beforeEach(async() => {
                await token.mint(WAD, { from: user1 });
            });

            it("allows burning", async () => {
                const tokenBalance = (await token.balanceOf(user1));

                const returnedEth = (await token.burn.call(tokenBalance, { from: user1 })).toString(); // .call transforms a transaction into a `view` function
                returnedEth.should.equal(tokenBalance.mul(WAD).div(priceWAD).toString());

                await token.burn(tokenBalance, { from: user1 });

                const newTokenBalance = (await token.balanceOf(user1)).toString();
                newTokenBalance.should.equal('0');
                const ethPool = (await token.ethPool()).toString();
                ethPool.should.equal((new BN('0')).toString());
            })

            it("price changes affect the debt ratio", async () => {
                const debtRatio = await token.debtRatio();
                const factor = new BN('2');
                await oracle.setPrice(price.mul(factor));
                let newDebtRatio = (await token.debtRatio()).toString();
                newDebtRatio.should.equal(debtRatio.div(factor).toString());

                await oracle.setPrice(price.div(factor));
                newDebtRatio = (await token.debtRatio()).toString();
                newDebtRatio.should.equal(debtRatio.mul(factor).toString());
            })

            it("price changes affect the token amount minted", async () => {
                const oneEth = WAD;
                const factor = new BN('2');
                await oracle.setPrice(price.mul(factor));
                await token.mint(oneEth, { from: user2 });
                let tokenBalance = (await token.balanceOf(user2)).toString();
                tokenBalance.should.equal(oneEth.mul(priceWAD.mul(factor)).div(WAD).toString());

                await oracle.setPrice(price.div(factor));
                await token.mint(oneEth, { from: user3 });
                tokenBalance = (await token.balanceOf(user3)).toString();
                tokenBalance.should.equal(oneEth.mul(priceWAD.div(factor)).div(WAD).toString());
            })

            it("price changes affect the underlying received on burning", async () => {
                const oneToken = WAD;
                const oneEth = WAD;
                const factor = new BN('2');
                await oracle.setPrice(price.mul(factor));
                let burned = (await token.burn.call(oneToken, { from: user1 })).toString();
                burned.should.equal(oneEth.mul(WAD).div(priceWAD.mul(factor)).toString());

                await oracle.setPrice(price.div(factor));
                burned = (await token.burn.call(oneToken, { from: user1 })).toString();
                burned.should.equal(oneEth.mul(WAD).div(priceWAD.div(factor)).toString());
            })

            it("returns the eth buffer amount", async () => {
                const ethPool = (await token.ethPool())
                ethPool.should.not.equal(ZERO.toString());
                
                let ethBuffer = (await token.ethBuffer()).toString();
                ethBuffer.should.equal(ZERO.toString());

                const factor = new BN('2');
                await oracle.setPrice(price.mul(factor));
                ethBuffer = (await token.ethBuffer()).toString();
                ethBuffer.should.equal(ethPool.div(factor).toString()); // Price multiplying by two frees half the eth pool

                await oracle.setPrice(price.div(factor));
                ethBuffer = (await token.ethBuffer()).toString();
                ethBuffer.should.equal(ethPool.mul(new BN('-1')).toString()); // Price dividing by two makes debt twice the pool, we are one "ethpool" short of debt ratio == 1.
            })
        });
    })
});