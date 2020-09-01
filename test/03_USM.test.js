const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const USM = artifacts.require("./USM.sol");
const TestOracle = artifacts.require("./TestOracle.sol");

const EVM_REVERT = "VM Exception while processing transaction: revert";

const toWei = (n) => {
    return web3.utils.toWei(n.toString(), 'ether');
}

const toEth = (n) => {
    return web3.utils.fromWei(n.toString(), 'ether')
}

require('chai')
    .use(require('chai-as-promised'))
    .should();

contract("USM", accounts => {

    let [deployer, user] = accounts;
    
    const price = new BN('25000');
    const shift = new BN('2');
    const WAD = new BN('1000000000000000000');
    const priceWAD = WAD.mul(price).div((new BN('10')).pow(shift));
    
    describe("mints and burns a static amount", () => {
        
        let oracle, usm;
        let etherPrice, etherPriceDecimalShift, ethDeposit, expectedMintAmount, mintFee;

        before(async () => {
            // Deploy contracts
            oracle = await TestOracle.new(price, shift, {from: deployer});
            usm = await USM.new(oracle.address, {from: deployer});

            // Setup variables
            // etherPrice = parseInt(await oracle.latestPrice());
            // etherPriceDecimalShift = parseInt(await oracle.decimalShift());
            // ethDeposit = 100;
            // mintAmount = "24975000000000000000000";

            // Mint
            // await usm.mint({from: user, value: toWei(ethDeposit)});
        });

        describe("deployment", () => {
            it("sets latest fum price", async () => {
                let latestFumPrice = (await usm.latestFumPrice()).toString();
                let MIN_ETH_AMOUNT = (await usm.MIN_ETH_AMOUNT()).toString();
                latestFumPrice.should.equal(MIN_ETH_AMOUNT);
            });    
        });

        it("allows minting USM", async () => {
            const oneEth = WAD;
            await usm.mint({ from: user, value: oneEth });
            const usmBalance = (await usm.balanceOf(user)).toString();
            usmBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString());
        })
        /*
        it("sets the correct debt ratio", async () => {
            let debtRatio = (await usm.debtRatio()).toString();
            debtRatio.toString().should.equal("999000000000000000");
        });

        it("returns the correct FUM price", async () => {
            let fumPrice = await usm.fumPrice();
            console.log(fumPrice.toString());
            //TODO
        });

        it("mints the correct amount", async () => {
            let erc20Minted = await usm.balanceOf(user);
            erc20Minted.toString().should.equal(mintAmount);
        });

        it("stores correct amount of ether", async () => {
            let usmEtherBalance = await web3.eth.getBalance(usm.address);
            usmEtherBalance.toString().should.equal(toWei(ethDeposit).toString());
            let ethPool = await usm.ethPool();
            toEth(ethPool.toString()).toString().should.equal(ethDeposit.toString());
        });

        it("updates the total supply", async () => {
            let usmTotalSupply = await usm.totalSupply();
            usmTotalSupply.toString().should.equal(mintAmount);
        });

        after(() => {
            describe("burns the static amount", () => {
                before(async () => {
                    // Burn
                    await usm.burn(mintAmount, {from: user});
                });

                it("burns the correct amount of usm", async () => {
                    let usmBalance = await usm.balanceOf(user);
                    usmBalance.toString().should.equal("0");
                });

                it("sets the correct debt ratio", async () => {
                    let debtRatio = (await usm.debtRatio()).toString();
                    debtRatio.toString().should.equal("0");
                });

                it("redeems ether back to the owner", async () => {
                    let newUsmEtherBalance = await web3.eth.getBalance(usm.address);
                    newUsmEtherBalance.toString().should.equal("599500000000000000");
                });

                it("updates the total supply", async () => {
                    let newUsmTotalSupply = await usm.totalSupply();
                    newUsmTotalSupply.toString().should.equal("0");
                });
            });
        }); */
    });

    /*
    describe("mints, then burns half without the price changing", () => {

        let oracle, usm;
        let halfUsmAmount, halfEtherAmount;
        let etherPrice, etherPriceDecimalShift, ethDeposit, expectedMintAmount;

        before(async () => {
            // Deploy contracts
            oracle = await TestOracle.new(price, decShift, {from: deployer});
            usm = await USM.new(oracle.address, {from: deployer});

            // Setup variables
            etherPrice = parseInt(await oracle.latestPrice());
            etherPriceDecimalShift = parseInt(await oracle.decimalShift());
            ethDeposit = 0.1;

            // Mint
            await usm.mint({from: user, value: toWei(ethDeposit)});

            // Setup half variables
            let usmMinted = await usm.balanceOf(user);
            halfUsmAmount = parseInt(usmMinted.toString()) / 2;
            halfEtherAmount = ethDeposit / 2;
            halfWithFees = 50299750000000000;

            // Burn
            // TODO - refactor burning as it won't allow burning if the debtRatio
            // is too high!
            await usm.burn(halfUsmAmount.toString(), {from: user});
        });

        it("burns half the amount of usm", async () => {
            let newBalance = await usm.balanceOf(user);
            newBalance.toString().should.equal(halfUsmAmount.toString());
        });

        it("redeems half the ether back to owner", async () => {
            let newUsmEthBalance = await web3.eth.getBalance(usm.address);
            newUsmEthBalance.toString().should.equal(halfWithFees.toString());
            let newEthPool = await usm.ethPool();
            newEthPool.toString().should.equal(halfWithFees.toString());
        });

        it("halves to total supply", async () => {
            let newUsmTotalSupply = await usm.totalSupply();
            newUsmTotalSupply.toString().should.equal(halfUsmAmount.toString());
        });
    });

    describe("mints, then burns half with the price doubling", () => {

        let oracle, usm;
        let halfUsmAmount, halfEtherAmount;
        let etherPrice, etherPriceDecimalShift, ethDeposit, expectedMintAmount;

        before(async () => {
            // Deploy contracts
            oracle = await TestOracle.new(price, decShift, {from: deployer});
            usm = await USM.new(oracle.address, {from: deployer});

            // Setup variables
            etherPrice = parseInt(await oracle.latestPrice());
            let doublePrice = etherPrice * 2;
            etherPriceDecimalShift = parseInt(await oracle.decimalShift());
            ethDeposit = 0.1;

            // Mint
            await usm.mint({from: user, value: toWei(ethDeposit)});

            // Double the price
            await oracle.setPrice(doublePrice.toString(), {from: deployer});

            // Check the debt ratio
            let debtRatio = await usm.debtRatio();
            debtRatio.toString().should.equal("499500000000000000");

            // Setup quarter variables
            let usmMinted = await usm.balanceOf(user);
            halfUsmAmount = parseInt(usmMinted.toString()) / 2;
            quarterEthAmount = ethDeposit / 4;

            // Burn
            await usm.burn(halfUsmAmount.toString(), {from: user});
        });

        it("burns the same amount of usm", async () => {
            let newBalance = await usm.balanceOf(user);
            newBalance.toString().should.equal(halfUsmAmount.toString());
        });

        it("updates debt ratio", async () => {
            let debtRatio = await usm.debtRatio();
            debtRatio.toString().should.equal("332335882128879123");
        });

        it("redeems the ether back to owner", async () => {
            // Calculate remaining ether
            let etherLeftInUsm = 75149875000000000;
            let newUsmEthBalance = await web3.eth.getBalance(usm.address);
            newUsmEthBalance.toString().should.equal(etherLeftInUsm.toString());
            let newEthPool = await usm.ethPool();
            newEthPool.toString().should.equal(etherLeftInUsm.toString());
        });

        it("halves to total supply", async () => {
            let newUsmTotalSupply = await usm.totalSupply();
            newUsmTotalSupply.toString().should.equal(halfUsmAmount.toString());
        });
    }); */
});