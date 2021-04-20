# Requirements for the mint/burn fee math


## The two key outputs: output amount (of USM/FUM/ETH), and `adjChangeFactor`

The formulas in `USM.sol`'s mint/burn fee math functions (`usmFromMint()`, `ethFromBurn()`, `fumFromFund()`, `ethFromDefund()`)
are confusing.  Perhaps they could safely be simplified, and perhaps in the future we'll find ways to simplify them.  But
meanwhile, here are the key criteria we were attempting to satisfy in devising them, so you can understand where the complexity
comes from.

Let's look at the most complex of the four: `ethFromDefund()`.  This function takes one input:
* `fumIn`, the amount of FUM the user is burning

And returns two outputs:
* `ethOut`, the amount of ETH to give back in return
* `adjShrinkFactor`, the factor by which to reduce the ETH/USD price in response to the burn operation

(The below includes some math-speak about integrals etc: feel free to skim over that stuff.  A lot of this was also touched on
in
[USM post #4: fee math decisions](https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f):
you may find the examples there helpful.)


## The "fee" is implied by the output amount/`adjChangeFactor` curves

We never actually calculate a "fee" "paid" by the user.  Instead we calculate `adjShrinkFactor` and `ethOut`, which *imply* a
fee: the further `adjShrinkFactor` gets below 1, the more the user's FUM sell price is dropping as they burn, and the less
`ethOut` they end up getting.  Conceptually, the "fee" is the difference between the ("zero-fee") `ethOut` they'd get if we
just calculated it as `fumIn` * `midFumPrice` (without sliding price), and the `ethOut` they actually get based on the price
sliding away from them.

In theory, if we know the `adjShrinkFactor` for any given input `fumIn`, that mathematical curve implies `ethOut`: the initial
FUM sell price and the `adjShrinkFactor` for each given `fumIn` gives us the marginal price, and `ethOut` is just the integral
of the resulting marginal price curve.  In practice, calculating exact integrals is often painful.  For `usmFromMint()` and
`ethFromBurn()` the integral is simple and we can calculate `usmOut`/`ethOut` exactly; for the FUM operations, `fumFromFund()`
and `ethFromDefund()`, we need approximations.

Whether we calculate the output amount from the `adjChangeFactor` or vice versa is a question of mathematical convenience.  For
`ethFromBurn()`, `ethOut` is easier to calculate first, so we calculate that and then derive the `adjGrowthFactor` from it.
For the other three (`usmFromMint()`, `fumFromFund()`, `ethFromDefund()`), the `adjChangeFactor` is easier to calculate, so we
derive the output amount from it.


## Requirements for the output amount/`adjChangeFactor` curves

So, what are some requirements for (eg) `ethFromDefund()`'s `ethOut` and `adjShrinkFactor` formulas?  (This list is a work in
progress...)

1. **Arbitrage-free.**  There must be no sequence of operations that lets a user reliably end up with strictly more tokens (eg,
   more USM and the same amount of ETH) than they started with.
   - Similar: the fee (implied, as described above) for every operation must be ≥ 0.
   <br><br>
2. **Increasing % fee.**  The fee should increase, *as a percentage of the input size,* as the input size increases.  So, tiny
   operations (not immediately preceded by similar operations jacking up the `bidAskAdjustment`) should pay a ~0% fee; larger
   operations should pay an increasing % fee.
   - As discussed in
     [USM post #2](https://jacob-eliosoff.medium.com/usm-minimalist-stablecoin-part-2-protecting-against-price-exploits-a16f55408216),
     rising fees like this are important to prevent small inaccuracies/delays in the price oracle from "being exploited in
     size."
   - One way of characterizing this is: if you do three of the same operation in quick succession (eg, call `mint(1 ETH)` three
     times), the *middle* operation should get a better average price (get more output USM per input ETH) than the three
     operations added together.
   <br><br>
3. **Increasing output amount.**  A larger input amount should get ≥ the output amount.
   - This seems trivial, but some fee formulas do risk violating it.  See eg
     [`ethFromDefund()`](https://github.com/usmfum/USM/blob/v0.4.0/contracts/USM.sol#L740): "Taking the geometric average is
     dicey in the `defund()` case: `fumSellPrice2` could be arbitrarily close to 0, which would make `avgFumSellPrice`
     arbitrarily close to 0, which would have the highly perverse result that a *larger* `fumIn` returns strictly *less* ETH!"
   <br><br>
4. **Path (near-)independence.**  Calling (eg) `mint(x ETH)` followed by `mint(y ETH)` should have approximately the same net
   effect (gas fees aside) as calling `mint(x+y ETH)`.
   - This is not a strict requirement: to perfectly achieve it would require always calculating exact integrals.  But
     avoiding glaringly different outcomes between the two is desirable.  In particular, it's ugly if the system incentivizes
     users to break up large operations into many small operations one after the other.  (That is, immediately after each
     other.  Whereas spreading out small operations over time, rather than one huge operation, is something we *do* want to
     incentivize, since most exploits we want to protect against take the form of sudden huge operations.)
   <br><br>
5. **No "shortcuts".**  There should be no roundabout way for a user to convert (eg) *x* ETH to USM, that yields more USM, than
   by directly calling `mint(x ETH)`.
   - [USM post #4](https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f)
     imagined a scenario that might violate this requirement: where a user calling `mint(e2 ETH) -> u USM` (pushing down the
     ETH/USD price), `fund(e3 ETH) -> f FUM` (taking advantage of the depressed ETH/USD price), `burn(u USM) -> e4 ETH`, could
     (hypothetically) get back more FUM than the simple `fund(e2+e3−e4 ETH)`.  We don't want to incentivize this: the functions
     should do their jobs well enough to make this sort of end run pointless.
   - The purpose of the ["FUM delta"](https://github.com/usmfum/USM/blob/v0.4.0/contracts/USM.sol#L654) we calculate in
     `fumFromFund()` and `ethFromDefund()` is to ensure that USM and FUM operations which loosely offset each other in terms of
     ETH exposure, like a `fund()` followed by a `burn()`, add up to sensible net results, rather than sneaky savings like
     above.
   <br><br>
6. **Gas efficiency.**
   - So, for example, the reason we [use an approximation](https://github.com/usmfum/USM/blob/v0.4.0/contracts/USM.sol#L597)
     for `usmOut` in `usmFromMint()`, rather than the (tractable) exact integral, is that testing showed the approximation
     [saved ~4k gas per `mint()` call](https://github.com/usmfum/USM/blob/v0.4.0/contracts/USM.sol#L593).  (And, of course,
     that the approximation is close enough for our purposes.)
   <br><br>
7. **Legible/intuitive math.**
   - We would love to do better on this front...  If, after browsing the comments in these four functions in
     [USM.sol](https://github.com/usmfum/USM/blob/master/contracts/USM.sol), you have simplifications/alternatives to suggest
     (that seem consistent with the rest of the requirements here), let us know!  (Eg,
     [open an issue.](https://github.com/usmfum/USM/issues/new))
