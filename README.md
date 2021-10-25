# USM ("Minimalist USD") Stablecoin

USM is an attempt to answer the question "What's the simplest possible decentralized stablecoin?"  The resulting project is a decentralized (ownerless and immutable), tightly pegged, open-source not-for-profit, minimalist ERC-20 stablecoin system, combining a stablecoin (1 USM = $1) + a "vol-coin" (FUM) with just four operations:

* `mint` (ETH->USM)
* `burn` (USM->ETH)
* `fund` (ETH->FUM)
* `defund` (FUM->ETH)

Read more in the [original series of 2020 Medium posts that sketched the design](https://jacob-eliosoff.medium.com/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8), and [@usmfum](https://twitter.com/usmfum) on Twitter.

## Networks & Addresses

### USM v1-rc1 (mainnet v1 release candidate)

On Oct 10, 2021, **v1 LAUNCHED!**  🎆🎉😬  v1-rc1 is the first uncapped mainnet USM release, which is exciting; but as a release _candidate_ v1-rc1 **may still be replaced by a v1-rc2 if significant problems are found** - keep an eye on [Twitter](https://twitter.com/usmfum) for news of any such developments.  See the [initial launch thread](https://twitter.com/usmfum/status/1447437647727763456) and give it a poke.

* Oracle: [0x7F360C88CABdcC2F2874Ec4Eb05c3D47bD0726C5](https://etherscan.io/address/0x7F360C88CABdcC2F2874Ec4Eb05c3D47bD0726C5)
* USM: [0x2a7FFf44C19f39468064ab5e5c304De01D591675](https://etherscan.io/address/0x2a7FFf44C19f39468064ab5e5c304De01D591675)
* FUM: [0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3](https://etherscan.io/address/0x86729873e3b88DE2Ab85CA292D6d6D69D548eDF3)
* USMView: [0x0aEbFe42154dEaE7e35AFA9727469e7F4a192b9d](https://etherscan.io/address/0x0aEbFe42154dEaE7e35AFA9727469e7F4a192b9d)
* USMWETHProxy: [0x19d4465Ea18d31fC113DF522994b68BA9a10A184](https://etherscan.io/address/0x19d4465Ea18d31fC113DF522994b68BA9a10A184)
* [Live v1 stats dashboard webpage](https://usmfum.github.io/USM-Stats/)

### USM v0.5 (mainnet pre-v1 temporary test deployment)

v0.5 is a test release, but on mainnet and full-featured, except that it becomes withdrawal-only after Oct 13.  (See our [Twitter thread](https://twitter.com/usmfum/status/1445245294187274240) about it.)  Feel free to play with it and report any issues, but soon!  Depending how this v0.5 is looking, the long-awaited v1 release candidate could come soon...

* Oracle: [0xE0924c0ab6BF613d0472093606074bA8243Ba56A](https://etherscan.io/address/0xE0924c0ab6BF613d0472093606074bA8243Ba56A)
* USM: [0x7816f1Ac2a8b8A2Ead4Bf5fE0B946a343C3282d6](https://etherscan.io/address/0x7816f1Ac2a8b8A2Ead4Bf5fE0B946a343C3282d6)
* FUM: [0x1d87CbD8df28729Ac12f5AfD0464Eb54C2870F95](https://etherscan.io/address/0x1d87CbD8df28729Ac12f5AfD0464Eb54C2870F95)

### USM v0.4 (Kovan testnet)

* Oracle: [0x8e91D25324833D62Fb3eC67aDEE26048696c8909](https://kovan.etherscan.io/address/0x8e91D25324833D62Fb3eC67aDEE26048696c8909)
* USM: [0x7dbC406E09c876C77949A45BBE4173Aa6CdF9470](https://kovan.etherscan.io/address/0x7dbC406E09c876C77949A45BBE4173Aa6CdF9470)
* FUM: [0x6Ee47863a96a488a53053Dea290CcF7f8979d6A9](https://kovan.etherscan.io/address/0x6Ee47863a96a488a53053Dea290CcF7f8979d6A9)
* USMView: [0x14E1657013b721B341eA27fcA47538C3B7416E4c](https://kovan.etherscan.io/address/0x14E1657013b721B341eA27fcA47538C3B7416E4c)
* Proxy: [0x4096DACc67Bae0F5b762D5DF98B343B0AaBAc1C0](https://kovan.etherscan.io/address/0x4096DACc67Bae0F5b762D5DF98B343B0AaBAc1C0)

### USM v0.1 ("Baby USM") - Mainnet

Baby USM is a "beta" version of USM. Baby USM expires on the 15th of January 2021 when it becomes withdraw-and-read-only. At this point, FUM and USM will be redeemable for ETH, but no more minting of either can occur.

Baby USM and Baby FUM is not redeemable for USM or FUM. It is for test and research purposes only.

* USM: [0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC](https://etherscan.io/address/0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC)
* FUM: [0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394](https://etherscan.io/address/0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394)

## How It Works

USM is pegged to United States dollar, and maintains its stable value by minting USM in exchange for ETH, using the price of ETH at the time of minting.

If ETH is worth $200, I deposit 1 ETH, I get 200 USM in return (minus a small minting fee). The same goes for burning, but in the opposite direction.

This is what's known as a **CDP: Collateralised Debt Position.**

The problem with CDPs is that if the asset used as collateral drops in value, which in our case is highly probable at any time due to the volatility of ETH, the contract could become undercollateralised. This is where the concept of Minimalist Funding Tokens, or FUM, come in.

For more information on how FUM de-risks USM, read [Jacob's original articles](https://jacob-eliosoff.medium.com/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8).
