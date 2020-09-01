const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const TestOracle = artifacts.require("./TestOracle.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("TestOracle", accounts => {
    const [deployer, user] = accounts;
    let oracle;

    const price = '25000';
    const decShift = '2';

    beforeEach(async() => {
        oracle = await TestOracle.new(price, decShift, {from: deployer});
    });

    describe("deployment", async () => {
        it("returns the correct price", async () => {
            let price = (await oracle.latestPrice()).toString();
            price.should.equal(price);
        });

        it("returns the correct decimal shift", async () => {
            let shift = (await oracle.decimalShift()).toString()
            shift.should.equal(decShift);
        })
    });
});