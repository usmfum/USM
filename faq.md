# USM Frequently Asked Questions


## Overview

### A. System Status
1. [Are there any urgent bugs or status updates?](#A1)
2. [What's the current latest production USM version?](#A2)
3. [What are the addresses of the current mainnet contracts?](#A3)
4. [Is there a user interface?](#A4)

### B. General
1. [What is USM?](#B1)
2. [What's a stablecoin?](#B2)
3. [What distinguishes USM from the many other stablecoins?](#B3)
4. [What's the big deal about being "decentralized" in this context?](#B4)
5. [What's the difference between USM and FUM?](#B5)
6. [What are the core operations of the system?](#B6)
7. [Who created USM?](#B7)
8. [Where can I learn more?](#B8)

### C. Using/Investing
1. [Why would I buy USM?](#C1)
2. [Why would I buy FUM?](#C2)
3. [What are the risks?](#C3)
4. [How do I buy them?](#C4)
5. [What happens after the "prefund" period ends at midnight UTC, evening of Oct 31, 2021?](#C5)
6. [Is there a way to see what the FUM price will be after the prefund period ends?](#C6)
7. [I accidentally sent mainnet ETH to the Kovan (testnet) contract/sent on the BSC chain rather than the ETH chain/mistyped
the recipient address - can I get a refund?](#C7)

### D. "Tokenomics"
1. [How was the initial token allocation distributed?](#D1)
2. [What's wrong with giving creators an initial allocation, to incentivize them to build a successful project?  Do you hate
capitalism?](#D2)
3. [Where do the user fees go?](#D3)
4. [How exactly are the fees calculated?](#D4)

### E. Future Plans
1. [Is the code audited?](#E1)
2. [Is this the final v1 release?](#E2)
3. [Will there be a v2?](#E3)
4. [What sorts of changes do you foresee in v2?](#E4)
5. [Will v1 USM (or FUM) be fungible with/exchangeable for v2 USM (FUM)?](#E5)
6. [Is USM available on blockchains other than Ethereum?](#E6)
<br>


## A. System Status

1. <a name="A1">**Are there any urgent bugs or status updates?**</a>

No, the v1 launch is still ongoing, no urgent developments.
<br>
<br>

2. <a name="A2">**What's the current latest production USM version?**</a>

v1-rc1 (v1 release candidate 1).
<br>
<br>

3. <a name="A3">**What are the addresses of the current mainnet contracts?**</a>

The v1-rc1 mainnet contracts are:
* Oracle: [0x7F360C88CABdcC2F2874Ec4Eb05c3D47bD0726C5](https://etherscan.io/address/0x7F360C88CABdcC2F2874Ec4Eb05c3D47bD0726C5)
* USM: [0x2a7FFf44C19f39468064ab5e5c304De01D591675](https://etherscan.io/address/0x2a7FFf44C19f39468064ab5e5c304De01D591675)
* FUM: [0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3](https://etherscan.io/address/0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3)
* USMView:
[0x0aEbFe42154dEaE7e35AFA9727469e7F4a192b9d](https://etherscan.io/address/0x0aEbFe42154dEaE7e35AFA9727469e7F4a192b9d)
* USMWETHProxy:
[0x19d4465Ea18d31fC113DF522994b68BA9a10A184](https://etherscan.io/address/0x19d4465Ea18d31fC113DF522994b68BA9a10A184)
<br>

4. <a name="A4">**Is there a user interface?**</a>

USM's user interface options are still quite primitive - mainly either via [sending to the contracts
directly](https://twitter.com/usmfum/status/1450995702927085571), or the [Etherscan
UI](https://etherscan.io/address/0x2a7fff44c19f39468064ab5e5c304de01d591675#writeContract) (but always double-check that you're
using the correct version of the contract!).  But there is also [Alex Roan](https://github.com/alexroan)'s spiffy [dashboard
webpage](https://usmfum.github.io/USM-Stats/), and more UIs may yet be built!
<br>
<br>


## B. General

1. <a name="B1">**What is USM?**</a>

USM ("Minimalist USD"), the token, is a new (launched Oct 2021) cryptocurrency intended to have certain properties: a
**stablecoin** (1 USM ≈ $1), **decentralized,** and relatively **minimalist.**  USM, the software project, is a smart contract
(blockchain-based computer program) running on the Ethereum blockchain, which lets you execute the key operations: `mint` and
`burn`.  So you could `mint` 100 new units of USM, by putting ~$100 worth of ETH into the smart contract; or `burn` 50 of those
USM units, getting back ~$50 worth of ETH.

One way to think of the USM smart contract is as a "stablecoin vending machine".  You put ETH in the slot, USM comes out the
bottom; or put USM in the slot, ETH comes out the bottom.  And like a vending machine, it runs autonomously, no human operator
involved.
<br>
<br>

2. <a name="B2">**What's a stablecoin?**</a>

This gets out of scope of this FAQ, but in brief a [stablecoin](https://en.wikipedia.org/wiki/Stablecoin) is, like BTC or ETH,
a type of cryptocurrency; but *unlike* BTC or ETH (whose dollar values swing wildly), one that tries to keep the price per unit
"stable" - typically, 1 unit of the coin ≈ $1.  Some of the best-known stablecoins include USDT (Tether), USDC and MakerDAO's
DAI.
<br>
<br>

3. <a name="B3">**What distinguishes USM from the many other stablecoins?**</a>

Probably the most distinctive thing about USM is that its smart contracts are deployed **immutably:** once launched, no one,
including the developers, can make any further changes to them - only relaunch fresh code and ask people to migrate over to it.
This ensures a high level of decentralization (there is no "admin password" that could be abused), but introduces other risks,
above all that bugs can't be fixed.
<br>
<br>

4. <a name="B4">**What's the big deal about being "decentralized" in this context?**</a>

Many of the most popular stablecoins, like USDT and USDC, are significantly centralized.  They're operated by companies, run by
executives, sitting on bank accounts.  And the company could go bankrupt, or the bank account could be frozen by regulators, or
the executive could abscond with the funds.  There are pros and cons to this: eg, if you accidentally send your USDT or USDC to
a mistyped address, you can contact the administrators and they may be able to refund you.  But the cryptocurrency dream is
tools for sending money that don't have these vulnerabilites.  It's technically impossible for us the creators of USM to
abscond with your money; the flip side is, if you send your USM to the wrong address, there's nothing we can do.  Welcome to
crypto!

There are several other stablecoins that aspire to be more decentralized than USDT or USDC.  The most famous is
[DAI](https://en.wikipedia.org/wiki/Dai_(cryptocurrency)): DAI is great, and if DAI realizes its goal of a solid $1 peg with no
centralized point of failure, USM may not be necessary.  But DAI and other decentralized stablecoins tend to have some
limitations: they're complex, or their peg floats around (sometimes 1 DAI = $0.95), or they have dependencies on centralized
tools/coins.

In short, different stablecoins have different tradeoffs, and USM is aiming to be on the "more decentralized, simpler,
tighter-peg" end of the field.
<br>
<br>

5. <a name="B5">**What's the difference between USM and FUM?**</a>

The core purpose of the USM system is simple: to make USM work as a stablecoin.  But in order for the system to work, another
token is needed: FUM ("Minimalist Funding"), the "vol-coin" to USM's stablecoin.  (See the [original USM blog
post](https://jacob-eliosoff.medium.com/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8).)  One way to think
of it is, the system sits on a pool of ETH (with significant market price exposure), and we "tranche" it into two subpools: one
made of USM (with no market price exposure), and one made of FUM (with *extra* market price exposure).  The risk "has to go
somewhere": the FUM holders take it so the USM holders don't have to.

In practice, the FUM price will swing even more wildly than the ETH price.  FUM holders also earn the fees charged by the
system on all `mint`/`burn` operations.  So buying-and-holding FUM may make sense if you expect USM to attract a lot of
(fee-paying) users, or if you expect the ETH/USD price to increase.  On the flip side, if the price of ETH drops, FUM holders
may be wiped out.  More risk, more reward.

The system depends on a balance of USM users (who aren't out to make money, just to use a stable cryptocoin) and FUM holders
(aiming to make profits, but meanwhile providing the collateral that keeps USM users safe).  The premise of the system is that
these two complementary types of users will find a healthy balance and the result will be a solidly-backed stablecoin.
<br>
<br>

6. <a name="B6">**What are the core operations of the system?**</a>

Four operations:
* `mint` (ETH->USM)
* `burn` (USM->ETH)
* `fund` (ETH->FUM)
* `defund` (FUM->ETH)
<br>

7. <a name="B7">**Who created USM?**</a>

USM is a collaboration between [Jacob Eliosoff](https://twitter.com/JaEsf), [Alberto Cuesta
Cañada](https://twitter.com/alcueca), and [Alex Roan](https://twitter.com/alexroan).  Jacob had the original idea and by the
end had written most of the code; Alberto and Alex provided the original impetus to turn the idea into working software, wrote
all the early code, and contributed lots of Solidity/dev expertise.  Alberto brought the most production Solidity experience,
Alex wrote the user interface...  So in one sense it's Jacob's project, but it would never have gotten built except as a
collaboration.

8. <a name="B8">**Where can I learn more?**</a>

* [This FAQ](./faq.md)
* The original series of four blog posts: [part
1](https://jacob-eliosoff.medium.com/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8), [part 2 (protecting
against price
exploits)](https://jacob-eliosoff.medium.com/usm-minimalist-stablecoin-part-2-protecting-against-price-exploits-a16f55408216),
[part 3 (uh this is happening
guys)](https://jacob-eliosoff.medium.com/usm-minimalist-stablecoin-part-3-uh-this-is-happening-guys-b2ec5b732e4), [part 4 (fee
math
decisions)](https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f).
These posts get quite technical so don't worry if your eyes glaze over in places...
* https://github.com/usmfum/USM has all the source code (including some extensive comments), plus issues with lots of past
design discussions
* [@usmfum](https://twitter.com/usmfum) on Twitter has the latest news/updates, and some bite-sized discussions
<br>


## C. Using/Investing

1. <a name="C1">**Why would I buy USM?**</a>

Mostly for the same practical reasons (many!) people buy other stablecoins, USDT/USDC/DAI and co:
* To exchange it for another cryptocurrency
* To park your (crypto) savings when you don't want to be long or short the market
* To send money to someone else: especially someone in another country (since traditional finance makes cross-border payments
tedious and pricey), but maybe just to pay back your friend for lunch (though Ethereum transaction fees currently make this
impractical unless it was a *very* expensive lunch)

In general, you wouldn't buy a stablecoin as an investment - by design it doesn't go up!  Though, one exception would be:
* To earn interest by "yield farming" your USM in a DeFi system like https://curve.fi/
<br>

2. <a name="C2">**Why would I buy FUM?**</a>

* To earn money (via user fees) if you think USM will be widely used
* To make a leveraged bet on ETH/USD
* To help collateralize the pool and strengthen the "1 USM = $1" peg
* To have fun and learn something fooling around with an experimental crypto project
<br>

3. <a name="C3">**What are the risks?**</a>

**USM is still very high-risk, experimental software.  DO NOT PUT MONEY INTO EITHER USM OR FUM THAT YOU CAN'T AFFORD TO
LOSE!!!**

Here are just a few of the specific scenarios that could lead to losses for USM/FUM users/holders:
* We have a bug.  An anonymous hacker drains the ETH pool late one night, all your USM and FUM is worthless.  There are many,
many precedents for this in other smart contracts...  And they had the luxury of fixing bugs after they deploy; we don't.
* Our code is perfect, but one or more of the price oracles we depend on have a bug, and a hacker exploits that.  In
particular, our "median of three" price oracle means that even if Chainlink goes completely haywire, the system is still no
worse than the less accurate of two Uniswap prices: but a bug in the Uniswap v3 contracts (or our libraries accessing those
contracts) could be fatal, since we depend on two Uniswap v3 pairs.
* The price oracle *code* works, but both USDC and USDT lose their dollar pegs, so that our ETH/USDC and ETH/USDT input prices
no longer reflect the true ETH/USD price.  Or Chainlink goes down + a hacker finds a way to manipulate the USDC price, etc.
* Our code has no *engineering* bugs, but it turns out our fundamental algorithms aren't robust: eg, our oracle is
slow/inaccurate enough that arbitrageurs are able to repeatedly "pick off" our stale prices.  Or, attackers are able to find a
way to move Uniswap's ETH/USDC and ETH/USDT prices, then do USM `mint`/`burn` ops, that yields them a net profit.
* The ETH/USD price drops sharply, the USM system "goes underwater" (value of ETH in pool < value of outstanding USM), and the
mechanisms we designed to keep the system working and recover from that scenario, don't work.
* The ETH/USD price drops, so your FUM's value drops too.  Because FUM acts like "leveraged ETH", an ETH price drop will
normally lead to an even larger drop in the price of FUM.  The fees FUM holders earn from USM users might offset the ETH price
drop; but they might not.  Holding FUM means accepting both significant technical risk to the USM system itself, and leveraged
market risk to ETH's price.
* There's nothing wrong with the system per se, but some combination of UI clunkiness and user error leads to an "oopsie"
moment: eg the user sending money to the wrong address/wrong version/on the wrong chain (eg BSC rather than ETH)/on mainnet
rather than testnet.  Please be careful when using the system!  Tech this new comes with some user-unfriendly moments and
again - if you send your coins to the wrong place, we can't get them back.
* Nobody uses the system, and you end up quietly withdrawing your money, minus some transaction fees.

But yeah, one risk you don't have to worry about is us changing the code and disappearing with your money.  Nobody can do that.
<br>
<br>

4. <a name="C4">**How do I buy them?**</a>

Getting your hands on some USM/FUM will be easier if you have some familiarity with Ethereum and a crypto wallet app like
[MetaMask](https://metamask.io/) (for browser or phone).  You'll want to use a "non-custodial" wallet: one where you, not the
business/exchange, hold the private keys to your cryptocoins.  (You generally can't store custom tokens like USM/FUM on a
custodial service like Coinbase.)  You'll also need to start by getting some ETH into your wallet: eg, by buying it on an
exchange like Coinbase and withdrawing it to your wallet.

Once you have some ETH, some ways to buy USM/FUM:
* **Direct send to the contracts.**  The most basic way is to send some of the ETH from your wallet to the USM contract (to get
USM) or to the FUM contract (to get FUM).  You should see some USM (or FUM) returned to your wallet in the same transaction:
see this [sample `fund`
transaction](https://etherscan.io/tx/0x09fea254b966beab9439d67b941b46d02c53594c21d1fded9e92158e18b213e9), sending 0.2 ETH to
the FUM contract and receiving 800 (0.2 / 0.00025) FUM tokens in return.  Just remember to specify a gas limit of 250,000 or
so, rather than the default 21,000.  (21,000 is the cost of a simple transfer: this is actually a complex operation.)
* **Etherscan's user interface.**  Go to the USM contract (see contract addresses/links at top), click Contract->Write
Contract, select the appropriate op (`mint`/`fund`), enter the amount of ETH to submit and your own recipient address, and
click Write.  This should achieve the same thing as the op-via-send option above.
* **A decentralized exchange like Uniswap.**  It should be possible to buy existing USM or FUM on exchanges, rather than mint
your own, once these tokens are listed there for sale (eg, trading pairs like USM/ETH or FUM/USDT), which anyone can add...
* **A centralized exchange like Coinbase.**  Though USM/FUM may take a long time to get listed there, if ever.  So in the short
term decentralized exchanges are probably a better way to go.
* **Mint in bulk with some friends.**  If several people want (eg) FUM, it can be cheaper to do one big `fund` operation and
then divvy up the tokens.  Cheaper because the "gas" (Ethereum network) cost of a `mint`/`fund` op is considerably higher than
the gas cost of sending already-minted tokens to a friend.
* **Rope in help from a crypto-savvy friend.**  Especially if you've never sent a cryptocurrency transaction before, in which
case all of the above options may be frustrating...  Crypto UX has a ways to go!

However you acquire the tokens though, you'll want to store them in some reasonably secure fashion.  For smallish amounts,
keeping them in your wallet (eg MetaMask) is reasonable, though you should make a paper backup (handwritten, not printed!) of
your wallet's "recovery passphrase".  This gets out of scope for this FAQ, but keep in mind that for regular people, an even
bigger hazard than theft or hacks is dumb stuff like losing your password.  There is no blockchain customer support line...
<br>
<br>

5. <a name="C5">**What happens after the "prefund" period ends at midnight UTC, evening of Oct 31, 2021?**</a>

Two things:
* The FUM/ETH price, fixed at 0.00025 ETH per FUM (4,000 FUM per ETH) during the prefund period, starts floating.  Whether it
floats up or down depends mainly on 1. whether ETH/USD goes up or down, 2. how many people are using the system (paying fees,
which push up the FUM price).
* The `defund` op (FUM->ETH), disabled during the prefund period, is enabled.
<br>

6. <a name="C6">**Is there a way to see what the FUM price will be after the prefund period ends?**</a>

Yes, you can go to the `USMView` contract (see contract addresses/links at the top above), Contract->Read Contract, and run the
`fumPrice(side, prefund)` function, setting `prefund` to 0.  (And, eg, `side` to 0, meaning buy price, rather than `side` = 1,
sell price.)

Passing in `prefund` = 1 should give a price of exactly 0.00025 ETH per FUM (outputs are scaled by 10<sup>18</sup>); right this
moment, passing in `prefund` = 0 gives 0.00025187, indicating that if the prefund period ended right now, the FUM price would
increase a smidgen.  But the greater significance of the prefund period is that once it ends, the FUM/ETH price may start
actively bouncing around.  (Especially if there's a lot of USM outstanding: the higher the debt ratio, ie, ratio of outstanding
USM to the ETH pool's value, the more wildly the FUM/ETH price will swing.)
<br>
<br>

7. <a name="C7">**I accidentally sent mainnet ETH to the Kovan (testnet) contract/sent on the BSC chain rather than the ETH
chain/mistyped the recipient address - can I get a refund?**</a>

NO!  Please be careful, caveat emptor - by the design of the system we have very little power to help in these situations.
Double-check your contract addresses, amounts, mainnet vs testnet.  If you're doing a large operation, verify a small one
first.  And in general most users should only be playing with USM with small amounts of money, at least in these early days
until it's more battle-tested/fully audited.

If the worst happens and you do send money to the wrong place, your only refund option may be to [petition Vitalik for a hard
fork](./vitalik_hard_fork.md).  The proof-of-stake "merge" hard fork is coming any month now, maybe he can get your change in
there.
<br>
<br>


## D. "Tokenomics"

1. <a name="D1">**How was the initial token allocation distributed?**</a>

There was no initial allocation: the system started off with 0 USM and 0 FUM outstanding.  The only way to create USM or FUM is
to deposit ETH via the standard public interface (`mint` and `fund`).
<br>
<br>

2. <a name="D2">**What's wrong with giving creators an initial allocation, to incentivize them to build a successful project?
Do you hate capitalism?**</a>

The model where creators/investors/other early stakeholders get a pre-allocated slice of the tokens, is totally reasonable (at
least in some configurations).  That's just not the model we chose for USM, which was meant as a fun open-source experiment to
build a useful public good, not a for-profit venture.  Having a preallocation would add a tiny bit of complexity to the code.
It would also open the system to the risk of someone releasing a forked version that stripped out the preallocation.

Of course there are genuine advantages to a model that explicitly aligns developer incentives with the financial success of the
project.  At least one seasoned (and supportive) observer predicted that USM would have its lunch eaten by projects with more
direct incentives for the founders and devs: a plausible criticism, especially given some of our lapses in focus this year...

The short of it is that there are different ways to do it, and this is the way we chose for USM.  Let other projects try other
models, and hopefully one of us (or more) will deliver a truly decentralized, tightly-pegged, good-UX stablecoin!
<br>
<br>

3. <a name="D3">**Where do the user fees go?**</a>

USM system fees are implicit, in the price you get when converting between ETH and USM or FUM.  If the external market price of
ETH is $4,000, and you call `mint(1 ETH)`, then a "0-fee" operation would be one where you get back exactly 4,000 USM.  If you
only get back 3,900 USM, then you've been implicitly "charged" a fee of 100 USM (or equivalently, 0.025 ETH, ~$100: 2.5% of the
trade).  That "fee" of 0.025 ETH stays in the system's ETH pool.  And FUM holders own a share of the pool (specifically, of the
"buffer" - the excess of ETH in the pool, beyond what's owed to USM holders: comparable to equity for a business).  So: fee
paid by user -> increase in the buffer -> increase in the unit price of FUM.

In short: the fees docked on mint/burn operations are kept in the system's pool of ETH, increasing the value of FUM holders'
share of that pool.
<br>
<br>

4. <a name="D4">**How exactly are the fees calculated?**</a>

This is a complex topic.  In brief:
* There are two different fees involved: the gas fee charged by the Ethereum network, which depends on how busy the network is,
and is outside USM's control; and the fee charged by the USM system itself.
* The USM system fee for a `mint`/`burn`/`fund`/`defund` op is based mainly on two factors: the size of the operation (how many
ETH relative to the ETH in the system's pool), and how many other similar operations have been executed recently.  A small
operation, not preceded by any other recent operations, will pay a ~0 fee.  A large operation, or (eg) a `mint` right after
several other `mints`, will pay a higher fee (get a worse price).
* If you want to dive into the fee math details, natural places to start are the four USM blog posts (especially part 4, ["fee 
math
decisions"](https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f));
and the comments for `usmFromMint()`, `ethFromBurn()`, `fumFromFund()` and `ethFromDefund()` in
[USM.sol](https://github.com/usmfum/USM/blob/master/contracts/USM.sol).
<br>


## E. Future Plans

1. <a name="E1">**Is the code audited?**</a>

Excellent question!  USM has been through two security audits, by
[Solidified](https://twitter.com/usmfum/status/1337502346952192000) and [ABDK](https://www.abdk.consulting/), and most of the
core code (eg, the integrals in the fee math) is unchanged since the (very thorough) ABDK audit.  But, we have introduced
nontrivial changes since that last audit: particularly the code that pulls from the Uniswap v3 price oracles.  So the short
answer is that despite the above checks, the deployed code has **not** been fully audited.

A third audit, of the now final (or at least much closer to final) code, is an option we're considering.  Audits are expensive
and we don't really have a budget; still, one thing that time has proven much more expensive than audits, is insufficient
auditing...  In the meantime, exercise the same caution you would when using any smart contract that hasn't been end-to-end
audited.
<br>
<br>

2. <a name="E2">**Is this the final v1 release?**</a>

Too soon to say.  v1-rc1 will be the final v1 release unless we discover (or you report!) a problem serious enough that we
judge it necessary to re-launch a v1-rc2.  It may be many months before we anoint v1-rc1 as the official v1 release: one idea
is to not do so until the v1-rc1 code has passed a fresh security audit.
<br>
<br>

3. <a name="E3">**Will there be a v2?**</a>

We have no current plans for a v2: ideally v1 will run smoothly forever.  But realistically, yes, a v2 is very likely to make
sense at some point - ideally because we make improvements/add features, but also possibly because, eg, one of our source price
oracles keels over.  Price oracles are a rapidly evolving technology and it's very likely that in a couple years (if not
months), better oracle options will be available than we had when we launched v1.  And of course, unlike many other projects,
we can't make changes to v1, only deploy fresh versions.  So a v2 is probably coming sometime.
<br>
<br>

4. <a name="E4">**What sorts of changes do you foresee in v2?**</a>

* Bugfixes...
* Improved (more accurate/robust/decentralized) price oracles
* New features?  But not too many - USM aims for simplicity over featurefulness.  It's even possible that future versions will
be *simpler* than v1, eg, if we find ways to simplify the (somewhat arcane) fee math that we're confident won't introduce
vulnerabilities.
* At some point probably [layer 2](https://ethereum.org/en/developers/docs/scaling/layer-2-rollups/) support?  (L2s are another
rapidly evolving technical landscape.)
<br>

5. <a name="E5">**Will v1 USM (or FUM) be fungible with/exchangeable for v2 USM (FUM)?**</a>

No: v1 and v2 will be distinct contracts with distinct tokens, so you'll need to withdraw your v1 USM/FUM from the v1 contract
for ETH (via `burn`/`defund` ops), then re-deposit it into the v2 contract (`mint`/`fund`).  We may provide a more seamless
migration mechanism between future versions (eg, v2 -> v3), but there are some [technical
hazards](https://twitter.com/usmfum/status/1450505282723979272), so we won't roll it out unless we're comfortable with the
safety and simplicity of the mechanism.  USM is minimalist by design!  ...Even if it makes things like version migrations a
little less convenient.

But anyway talk of v2 is still entirely hypothetical at this point.
<br>
<br>

6. <a name="E6">**Is USM available on blockchains other than Ethereum?**</a>

Not yet, though there's no fundamental reason it couldn't be (and some other blockchains would give relief from Ethereum's high
transaction fees).  The main obstacle is the need for a robust decentralized price oracle (or preferably three or five of them,
so we can take the median), like Uniswap's v3 oracles.  But in principle, separate USM contracts could be deployed on many
different blockchains - even on Bitcoin!

(Just kidding, you could never make USM work on Bitcoin.  But lots of other chains, sure.)
