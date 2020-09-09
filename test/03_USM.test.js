const { BN, expectRevert } = require('@openzeppelin/test-helpers');

const USM = artifacts.require("./USM.sol");
const FUM = artifacts.require("./FUM.sol");
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
    const ZERO = new BN('0');
    const WAD = new BN('1000000000000000000');
    const oneEth = WAD;
    const oneUsm = WAD;
    const priceWAD = WAD.mul(price).div((new BN('10')).pow(shift));

    describe("mints and burns a static amount", () => {

        let oracle, usm;
        let etherPrice, etherPriceDecimalShift, ethDeposit, expectedMintAmount, mintFee;

        beforeEach(async () => {
            // Deploy contracts
            oracle = await TestOracle.new(price, shift, {from: deployer});
            usm = await USM.new(oracle.address, {from: deployer});
            fum = await FUM.at(await usm.fum());

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
                // The fum price should start off equal to $1, in ETH terms = 1 / price:
                latestFumPrice.should.equal(WAD.mul(WAD).div(priceWAD).toString());
            });
        });

        describe("minting and burning", () => {
            it("doesn't allow minting USM before minting FUM", async () => {
                await expectRevert(
                    usm.mint({ from: user, value: oneEth }),
                    "Must fund before minting"
                );
            });

            it("allows minting FUM", async () => {
                const fumPrice = (await usm.latestFumPrice()).toString();

                await usm.fund({ from: user, value: oneEth });
                const fumBalance = (await fum.balanceOf(user)).toString();
                fumBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString());

                const newEthPool = (await usm.ethPool()).toString();
                newEthPool.should.equal(oneEth.toString());

                const newFumPrice = (await usm.latestFumPrice()).toString();
                newFumPrice.should.equal(fumPrice); // Funding doesn't change the fum price
            });

            describe("with existing FUM supply", () => {
                beforeEach(async () => {
                    await usm.fund({ from: user, value: oneEth });
                });

                it("allows minting USM", async () => {
                    const fumPrice = (await usm.latestFumPrice()).toString();

                    await usm.mint({ from: user, value: oneEth });
                    const usmBalance = (await usm.balanceOf(user)).toString();
                    usmBalance.should.equal(oneEth.mul(priceWAD).div(WAD).toString());

                    const newFumPrice = (await usm.latestFumPrice()).toString();
                    newFumPrice.should.equal(fumPrice); // Minting doesn't change the fum price if buffer is 0
                });

                it("doesn't allow minting with less than MIN_ETH_AMOUNT", async () => {
                    const MIN_ETH_AMOUNT = await usm.MIN_ETH_AMOUNT();
                    // TODO: assert MIN_ETH_AMOUNT > 0
                    await expectRevert(
                        usm.mint({ from: user, value: MIN_ETH_AMOUNT.sub(new BN('1')) }),
                        "Must deposit more than 0.001 ETH"
                    );
                });

                describe("with existing USM supply", () => {
                    beforeEach(async () => {
                        await usm.mint({ from: user, value: oneEth });
                    });

                    it("allows burning USM", async () => {
                        const usmBalance = (await usm.balanceOf(user)).toString();
                        const fumPrice = (await usm.latestFumPrice()).toString();

                        await usm.burn(usmBalance, { from: user });
                        const newUsmBalance = (await usm.balanceOf(user)).toString();
                        newUsmBalance.should.equal('0');
                        // TODO: Test the eth balance just went up. Try setting gas price to zero for an exact amount

                        const newFumPrice = (await usm.latestFumPrice()).toString();
                        newFumPrice.should.equal(fumPrice); // Burning doesn't change the fum price if buffer is 0
                    });

                    it("doesn't allow burning with less than MIN_BURN_AMOUNT", async () => {
                        const MIN_BURN_AMOUNT = await usm.MIN_BURN_AMOUNT();
                        // TODO: assert MIN_BURN_AMOUNT > 0
                        await expectRevert(
                            usm.burn(MIN_BURN_AMOUNT.sub(new BN('1')), { from: user }),
                            "Must burn at least 1 USM"
                        );
                    });

                    it("doesn't allow burning USM if debt ratio under 100%", async () => {
                        const debtRatio = (await usm.debtRatio()).toString();
                        const factor = new BN('2');
                        debtRatio.should.equal(WAD.div(factor).toString());

                        await oracle.setPrice(price.div(factor).div(factor)); // Dropping eth prices will push up the debt ratio
                        const newDebtRatio = (await usm.debtRatio()).toString();
                        newDebtRatio.should.equal(WAD.mul(factor).toString());

                        await expectRevert(
                            usm.burn(oneUsm, { from: user }),
                            "Cannot burn with debt ratio below 100%"
                        );
                    });
                });
            });
        });
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
