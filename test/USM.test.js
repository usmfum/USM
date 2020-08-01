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

    describe("mints and burns a static amount", () => {
        let oracle, usm;
        let etherPrice, etherPriceDecimalShift, ethDeposit, expectedMintAmount;
        let erc20Minted, usmEtherBalance, usmTotalSupply;

        before(async () => {
            oracle = await USDOracle.new({from: deployer});
            usm = await USM.new(oracle.address, {from: deployer});
            etherPrice = parseInt(await oracle.latestPrice());
            etherPriceDecimalShift = parseInt(await oracle.decimalShift());
            ethDeposit = 8;
            expectedMintAmount = ether(ethDeposit * (etherPrice / (10**etherPriceDecimalShift)));
            //mint
            await usm.mint({from: deployer, value: ether(ethDeposit)});
        });

        it("mints the correct amount", async () => {
            erc20Minted = await usm.balanceOf(deployer);
            erc20Minted.toString().should.equal(expectedMintAmount.toString());
        });

        it("stores correct amount of ether", async () => {
            usmEtherBalance = await web3.eth.getBalance(usm.address);
            usmEtherBalance.toString().should.equal(ether(ethDeposit).toString());
        });

        it("updates the total supply", async () => {
            usmTotalSupply = await usm.totalSupply();
            usmTotalSupply.toString().should.equal(erc20Minted.toString());
        });

        after(() => {
            describe("burns the static amount", () => {
                before(async () => {
                    //burn
                    await usm.burn(erc20Minted, {from: deployer});
                });

                it("burns the correct amount of coins", async () => {
                    erc20Minted = await usm.balanceOf(deployer);
                    erc20Minted.toString().should.equal("0");
                });

                it("redeems ether back to the owner", async () => {
                    usmEtherBalance = await web3.eth.getBalance(usm.address);
                    usmEtherBalance.toString().should.equal("0");
                });

                it("updates the total supply", async () => {
                    usmTotalSupply = await usm.totalSupply();
                    usmTotalSupply.toString().should.equal("0");
                })
            });
        });
    });
});