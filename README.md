# USM - Minimalist USD Stablecoin

Originally proposed by [@jacob-eliosoff](https://github.com/jacob-eliosoff) in [this Medium article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8), USM is an attempt to answer the question "What is the simplest possible decentralised stablecoin?"

## How It Works

USM is pegged to United States Dollar which maintains its stable value by minting USM in exchange for ETH, using the price of ETH at the time of minting.

If ETH is worth $200, I deposit 1 ETH, I get 200 USM in return (minus a small minting fee). The same goes for burning, but in the opposite direction.

This is what's known as a **CDP: Collateralised Debt Position.**

The problem with CDPs is that if the asset used as collateral drops in value, which in our case is highly probable at any time due to the volatility of ETH, the contract could become undercollateralised. This is where the concept of Minimalist Funding Tokens, or FUM, come in.

For more information on how FUM de-risks USM, read [Jacob's original article](https://medium.com/@jacob.eliosoff/whats-the-simplest-possible-decentralized-stablecoin-4a25262cf5e8).
