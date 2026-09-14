# TheRewarder - Recon day(day 43, sep 10)

**what the protocol says it does**
The protocol is a reward distributor that hands out two tokens(DVT and WETH) to a prederfined list of beneficiaries. Eligible users claim rewards by submitting a merkle proof hat they're on the approved list. The contract is gas-optimized to let a user claim multiple tokens in a single transaction.

**Invariants / the rule that should always hold**

- Only addresses in the Merkle tree can claim, and only for their exact allocated amount.
- Sum of all successful claims for a token ≤ total funded for that distribution.
- Only the owner can create distributions or receive swept tokens via `clean`.
- `nextBatchNumber` only increases, one at a time, per token; roots are immutable once set.
- Contract's actual token balance ≥ `remaining` at all times.
- `remaining` decreases by exactly the amount transferred on every successful claim.
- No matter how a user calls claimRewards, they cannot end up having received payout for the same (token, batch) pair more than once.

**what i start with**

- Player is a listed beneficiary: in both the DVT and WETH Merkle trees — so I have valid proofs I can present.
- No special permissions or extra funds: just a regular user with no ETH.
- The distributor is fully funded: with both DVT and WETH ready to be claimed.
- The `claimRewards` function is open to anyone: no access control on claiming. The only eligibility gate is the Merkle proof.
- A recovery address is designated: where all stolen funds must end up.

**suspicion list (what looked off on first read)**

- No access control on `createDistribution` — anyone can create a distribution.
- Batched claims across tokens "for gas savings" — gas optimizations usually mean a check got moved out of a hot loop. Worth tracing whether any invariant is now under-protected.
- `_setClaimed` runs only when the token changes or on the last iteration — not on every claim. But the token transfer runs every iteration. So payouts happen more often than the "already claimed?" check.
- Merkle proof verification is stateless — the same proof stays valid forever. Nothing tracks whether a proof has been "used."
- The bitmap only tracks "claimed or not" — there's no count. If someone claims the same batch multiple times in one call, the bitmap can't tell the difference.

**where it breaks**
Inside `claimRewards`, the token transfer runs on every loop iteration, but `_setClaimed` (the "already claimed?" check plus bitmap update) only runs when the token changes or on the last iteration. Payout and bookkeeping run at different frequencies — that gap is the bug.

The bitmap can only store 0 or 1 per batch, so it has no way to represent "this batch was submitted N times in one call." Merkle proof verification is stateless, so the same proof stays valid forever. Nothing tracks whether a proof has been used before.

**attack idea**
Build one `claimRewards` call containing many identical `Claim` structs — same batch, same amount, same proof — grouped by token (all DVT copies first, then all WETH copies). Each identical claim triggers a fresh payout, but the bitmap only records one claim per token group. Repeat enough copies to drain each pot, then forward everything to the recovery address.

**how it plays out in the code**
For each duplicate DVT claim, the Merkle proof verifies (stateless math, same inputs → same result), and `dvt.transfer(msg.sender, amount)` fires. `_setClaimed` doesn't run yet because the token hasn't changed.

When the loop hits the first WETH claim, the token changes → `_setClaimed` fires once for DVT. It checks the bitmap for overlap: no bit was previously set (this is the player's first claim), so it approves, marks batch 0 claimed, and subtracts the _accumulated_ amount (all N copies combined) from `remaining`.

The same happens for WETH: N payouts run, then on the last iteration `_setClaimed` fires once for WETH.

Grouping is critical. If claims were interleaved (`[DVT, WETH, DVT, WETH]`), each token change would flush the bitmap, and the second DVT flush would collide with the first — the bitmap check would catch the duplicate and revert with `AlreadyClaimed`. Grouping ensures each token gets flushed only once, after all its duplicates have already paid out.

**what i will do differently**
Whenever I see a function described as "gas-optimized" or "batched," I'll look for the check that got moved out of the loop — that's usually where the bug is hiding.

For any loop that transfers value, I'll ask: _what runs every iteration vs. what runs only sometimes? Can I make those two disagree?_

And I'll treat stateless checks (Merkle proofs, signatures, hashes) inside a loop as a red flag. "Valid" isn't the same as "unused" — the same proof stays valid forever, so a loop that only checks validity won't catch a user submitting the same claim over and over.

**fix**
The root problem is that the "already claimed?" check runs less often than the payout. The fix is to make sure that check happens _before_ every payout, so duplicates get caught right away.

A few ways to do this:

- **Simplest fix:** call `_setClaimed` on every iteration instead of once per token group. The bitmap update happens each time, so duplicates trip the check immediately. Costs more gas but the bug is gone.

- **Cheaper fix:** keep the accumulator, but before adding a bit into `bitsSet`, check whether that bit is _already_ set inside the current call. If it is, the user is submitting the same batch twice — revert. This catches duplicates within one call without giving up the gas savings.

- **Extra safety:** as a belt-and-braces measure, reject any array where the same (batchNumber, tokenIndex) pair appears more than once.

All of these close the same gap: they make sure payout and bookkeeping happen at the same frequency, so a duplicate can never sneak through.
