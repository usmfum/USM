const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const TestOracle = artifacts.require("./TestOracle.sol");
const BufferedToken = artifacts.require("./MockBufferedToken.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("BufferedToken", accounts => {
    const [deployer, user] = accounts;
    let token;

    const price = new BN('25000');
    const shift = new BN('2');
    const WAD = new BN('1000000000000000000');
    const priceWAD = WAD.mul(price).div((new BN('10')).pow(shift));
    
    beforeEach(async() => {
        oracle = await TestOracle.new(price, shift, { from: deployer });
        token = await BufferedToken.new(oracle.address, "Name", "Symbol", { from: deployer });
    });

    describe("deployment", async () => {
        it("returns the correct price", async () => {
            let oraclePrice = (await oracle.latestPrice()).toString();
            oraclePrice.should.equal(price.toString());
        });

        it("returns the correct decimal shift", async () => {
            let decimalshift = (await oracle.decimalShift()).toString()
            decimalshift.should.equal(shift.toString());
        })
    });

    describe("functionality", async () => {
        it("returns the oracle price in WAD", async () => {
            let oraclePrice = (await token.oraclePrice()).toString()
            oraclePrice.should.equal(priceWAD.toString());
        })

        it("returns the value of eth in usm", async () => {
            const oneEth = WAD;
            const equivalentUSM = oneEth.mul(priceWAD).div(WAD)
            let usmAmount = (await token.ethToUsm(oneEth)).toString()
            usmAmount.should.equal(equivalentUSM.toString());
        })

        it("returns the value of usm in eth", async () => {
            const oneUSM = WAD;
            const equivalentEth = oneUSM.mul(WAD).div(priceWAD)
            let ethAmount = (await token.usmToEth(oneUSM)).toString()
            ethAmount.should.equal(equivalentEth.toString());
        })

        it("returns the debt ratio as zero", async () => {
            const ZERO = new BN('0');
            let debtRatio = (await token.debtRatio()).toString()
            debtRatio.should.equal(ZERO.toString());
        })

        it("updates the debt ratio on mint", async () => {
            await token.mint({ from: user, value: WAD });
            let debtRatio = (await token.debtRatio()).toString()
            debtRatio.should.equal(WAD.toString());
        })

        describe("with a positive supply", async () => {
            beforeEach(async() => {
                await token.mint({ from: user, value: WAD });
            });

            it("price changes affect the debt ratio", async () => {
                const debtRatio = await token.debtRatio();
                const factor = new BN('2');
                await oracle.setPrice(price.mul(factor));
                let newDebtRatio = (await token.debtRatio()).toString()
                newDebtRatio.should.equal(debtRatio.div(factor).toString());

                await oracle.setPrice(price.div(factor));
                newDebtRatio = (await token.debtRatio()).toString()
                newDebtRatio.should.equal(debtRatio.mul(factor).toString());
            })
        });
    })
});