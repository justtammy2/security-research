# Puppet - Recon (Day 22, Aug 20)

**What the protocol says it does:**
Puppet is a lending pool. You can borrow DVT tokens, but you have to leave behind ETH worth 2x what you borrow. If you want 100 DVT, you leave ETH worth 200 DVT.

**The rule that should always be true:**
Every borrower's ETH deposit should be worth at least 2x the DVT they took. No way to borrow more than your deposit is worth.

**Where the rule breaks:**
The pool has no real way of knowing what DVT is worth. It just asks a tiny nearby market for the price and trusts whatever answer it gets. That market is small and anyone can trade in it, so anyone can change the answer.

That market only has 10 ETH and 10 DVT inside it. Anyone can walk up and trade with it. If someone messes with the balances in that market, the "price" the pool sees changes.
The lending pool uses the Uniswap exchange's current token/ETH balance as its price oracle.
A manipulable spot price from a DEX is being trusted as an oracle for a lending protocol

**How the bug works in code:**

- `calculateDepositRequired()` figures out how much ETH you need to deposit.
- It calls `_computeOraclePrice()` to get the DVT price.
- `_computeOraclePrice()` just divides the ETH in the Uniswap pool by the DVT in the Uniswap pool. Whatever's in there right now.
- No safety checks. No average over time. No second source to cross-check.

**Attack idea:**
I have 1000 DVT. The Uniswap market only has 10 DVT. If I dump my DVT into that market, DVT becomes "cheap" in the pool's eyes. Once it's cheap enough, my 25 ETH is enough to borrow all 100,000 DVT from the lending pool.

**What I start with:**
25 ETH and 1000 DVT. I have 100x more DVT than the whole Uniswap market has. That's the imbalance that makes the attack possible.

**Fix shape:**
don't read prices from something a single actor can move within a single transaction. Two categories:

- Off-chain oracles e.g Chainlink, Pyth, RedStone
- TWAPs e.g time-weighted average prices, e.g. Uniswap V3's built-in oracle
