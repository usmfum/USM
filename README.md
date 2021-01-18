# USM - Minimalist USD Stablecoin

Originally proposed by [@jacob-eliosoff](https://github.com/jacob-eliosoff) in [this Medium article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8), USM is an attempt to answer the question "What is the simplest possible decentralised stablecoin?"

## Networks & Addresses

### USM v0.2

Oracle: [0x5632b97cc9606FEFfd6a6F59AF60D4fE045Ac19F](https://kovan.etherscan.io/address/0x5632b97cc9606FEFfd6a6F59AF60D4fE045Ac19F)
USM: [0xa87dF30Cc25f57c255C1588d152ce927B00DDB1c](https://kovan.etherscan.io/address/0xa87dF30Cc25f57c255C1588d152ce927B00DDB1c)
FUM: [0xe7c277fd339c38a093139935a1c5a9cc8cf8c7f7](https://kovan.etherscan.io/address/0xe7c277fd339c38a093139935a1c5a9cc8cf8c7f7)
USMView: [0xEEB40160Be35FfCe0f54a4ea40f447601a48f21b](https://kovan.etherscan.io/address/0xEEB40160Be35FfCe0f54a4ea40f447601a48f21b)
Proxy: [0xa085f278B7D496A68FeCC964931B8fbF6CA3b689](https://kovan.etherscan.io/address/0xEEB40160Be35FfCe0f54a4ea40f447601a48f21b)

### USM v0.1 (Baby) - Mainnet

[Live Stats](https://usmfum.github.io/USM-Stats/)

Baby USM is a "beta" version of USM. Baby USM expires on the 15th of January 2021 when it becomes withdraw-and-read-only. At this point, FUM and USM will be redeemable for ETH, but no more minting of either can occur.

Baby USM and Baby FUM is not redeemable for USM or FUM. It is for test and reserach purposes only.

USM: [0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC](https://etherscan.io/address/0x03eb7Ce2907e202bB70BAE3D7B0C588573d3cECC)

FUM: [0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394](https://etherscan.io/address/0xf04a5D82ff8a801f7d45e9C14CDcf73defF1a394)

### Kovan

USM: [0x21453979384f21D09534f8801467BDd5d90eCD6C](https://kovan.etherscan.io/address/0x21453979384f21D09534f8801467BDd5d90eCD6C)

FUM: [0x96F8F5323Aa6CB0e6F311bdE6DEEFb1c81Cb1898](https://kovan.etherscan.io/address/0x96F8F5323Aa6CB0e6F311bdE6DEEFb1c81Cb1898)

## How It Works

USM is pegged to United States dollar, and maintains its stable value by minting USM in exchange for ETH, using the price of ETH at the time of minting.

If ETH is worth $200, I deposit 1 ETH, I get 200 USM in return (minus a small minting fee). The same goes for burning, but in the opposite direction.

This is what's known as a **CDP: Collateralised Debt Position.**

The problem with CDPs is that if the asset used as collateral drops in value, which in our case is highly probable at any time due to the volatility of ETH, the contract could become undercollateralised. This is where the concept of Minimalist Funding Tokens, or FUM, come in.

For more information on how FUM de-risks USM, read [Jacob's original article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8).

**UPDATE:** Read part two on [protecting against price exploits](https://medium.com/@jacob.eliosoff/usm-minimalist-stablecoin-part-2-protecting-against-price-exploits-a16f55408216).
