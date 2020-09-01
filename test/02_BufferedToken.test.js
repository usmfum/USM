const TestOracle = artifacts.require("./TestOracle.sol");
const BufferedToken = artifacts.require("./MockBufferedToken.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("BufferedToken", accounts => {
    const [deployer, user] = accounts;
    let token;

    const price = '25000';
    const decShift = '2';
    const priceWAD = '250000000000000000000'; // TODO: This should be encoded in a javascript function that combines price and decShift
    
    beforeEach(async() => {
        oracle = await TestOracle.new(price, decShift, {from: deployer});
        token = await BufferedToken.new(oracle.address, "Name", "Symbol", {from: deployer});
    });

    describe("deployment", async () => {
        it("returns the correct price", async () => {
            let oraclePrice = (await oracle.latestPrice()).toString();
            price.should.equal(oraclePrice);
        });

        it("returns the correct decimal shift", async () => {
            let shift = (await oracle.decimalShift()).toString()
            shift.should.equal(decShift);
        })
    });

    describe("functionality", async () => {
        it("returns the oracle price in WAD", async () => {
            let oraclePrice = (await token.oraclePrice()).toString()
            priceWAD.should.equal(oraclePrice);
        })
    })
});