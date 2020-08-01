const USM = artifacts.require("./USM.sol");
const USDOracle = artifacts.require("./USDOracle.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

const ether = (n) => {
    return web3.utils.toWei(n.toString(), 'ether');
}

const usd = (n) => {
    return web3.utils.fromWei(n.toString(), 'ether')
}

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("USM", accounts => {
    let deployer = accounts[0];
    let minter1 = accounts[1];
    let oracle, usm;

    beforeEach(async () => {
        oracle = await USDOracle.new({from: deployer});
        usm = await USM.new(oracle.address, {from: deployer});
    });

    describe("deployment", async () => {
        it("mints and burns a static amount", async () => {
            let etherPrice = parseInt(await oracle.latestPrice());
            let etherPriceDecimalShift = parseInt(await oracle.decimalShift());
            
            let ethDeposit = 12;
            let expectedMintAmount = ether(ethDeposit * (etherPrice / (10**etherPriceDecimalShift)));

            //mint
            await usm.mint({from: minter1, value: ether(ethDeposit)});
            let erc20Minted = await usm.balanceOf(minter1);
            erc20Minted.toString().should.equal(expectedMintAmount.toString());
            let usmEtherBalance = await web3.eth.getBalance(usm.address);
            usmEtherBalance.toString().should.equal(ether(ethDeposit).toString());
            let usmTotalSupply = await usm.totalSupply();
            usmTotalSupply.toString().should.equal(erc20Minted.toString());

            //burn
            await usm.burn(erc20Minted, {from: minter1});
            erc20Minted = await usm.balanceOf(minter1);
            erc20Minted.toString().should.equal("0");
            usmEtherBalance = await web3.eth.getBalance(usm.address);
            usmEtherBalance.toString().should.equal("0");
            usmTotalSupply = await usm.totalSupply();
            usmTotalSupply.toString().should.equal("0");

        });
    });
});