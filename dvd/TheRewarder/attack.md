# TheRewarder - attack

## hypothesis

The player can drain both the DVT and WETH pots by submitting one `claimRewards` call containing many duplicate claims. The payout runs every iteration but the bookkeeping only runs once per token group. So identical claims get paid multiple times while being recorded only once.

## preconditions

- Player is a listed beneficiary in both the DVT and WETH Merkle trees, so valid proofs exist.
- The DVT and WETH JSON files are readable off-chain, so the player's index, amount, and proof can be computed.
- `claimRewards` has no access control beyond Merkle proof verification.
- The distributor is funded and has not been fully claimed by other beneficiaries.
- The player's bitmap for batch 0 is still empty on both tokens (no prior claim by the player).

## attack steps

1. Read the DVT and WETH JSON files and find the player's index and allocated amount in each.
2. Rebuild the Merkle leaves and compute the player's proof for each tree.
3. Compute the number of duplicates per token: `remaining / playerAllocation`.
4. Build one `Claim[]` array: all DVT duplicates first, then all WETH duplicates. Same batch number, amount, tokenIndex, and proof within each group.
5. Call `claimRewards` once with the crafted array and the `[DVT, WETH]` token list.
6. Transfer the player's entire DVT and WETH balances to `recovery`.

## why each step works

- **Step 1–2:** the tree data is public. Anyone can rebuild the leaves and compute a valid proof for any listed beneficiary.
- **Step 3:** integer division caps duplicates at what the pot can pay without underflowing `remaining`. Leftover is the tolerated dust.
- **Step 4 (grouping):** `claimRewards` flushes `_setClaimed` when the token changes. Grouping keeps flushes from firing between duplicates. Interleaving would revert on the second flush of the same token, when the bitmap already shows batch 0 as claimed.
- **Step 5 (single call):** Merkle proof verification is stateless — the same proof passes on every iteration. Payout fires every iteration. Bookkeeping fires only once per token group. The bitmap can only represent claimed/unclaimed, not a count, so N duplicate payouts collapse into one recorded claim.
- **Step 6:** the success check requires all stolen funds to end up at `recovery`, not on the player's address.

## summary

The whole exploit is one function call with a carefully built array. Both pots get drained in the same transaction.

It works because three things line up:

1. **Merkle proofs never expire.** Verifying a proof is pure math — the same proof passes every time it's checked. Nothing tracks whether a proof has been used before.

2. **The bitmap can only say "claimed or not."** There's no counter. It can't tell the difference between "claimed once" and "claimed a hundred times."

3. **`_setClaimed` only runs once per token, not once per claim.** The gas optimization inside `claimRewards` accumulates the bitmap update and only flushes it when the token changes or the loop ends.

Meanwhile, the actual token transfer runs on _every_ iteration. So when I submit a hundred identical claims for DVT, the transfer fires a hundred times but the bitmap gets updated just once at the end.

The result: the recovery address ends up with almost all of the DVT and WETH. The only thing left in the distributor is a tiny amount of dust — whatever the player's allocation didn't divide evenly into.

## diagram

## diagram

​`
                    ┌─────────────────────────────────────┐
                    │   Build inputClaims array (grouped) │
                    └─────────────────────────────────────┘
                                     │
              ┌──────────────────────┴──────────────────────┐
              │                                             │
              ▼                                             ▼
     N × DVT copies (identical)              M × WETH copies (identical)
     [DVT, DVT, DVT, ..., DVT,                WETH, WETH, WETH, ..., WETH]
              │                                             │
              └──────────────────────┬──────────────────────┘
                                     ▼
                    ┌─────────────────────────────────────┐
                    │   distributor.claimRewards(array)   │
                    └─────────────────────────────────────┘
                                     │
                                     ▼
          ╔══════════════════════════════════════════════════╗
          ║              For each iteration:                 ║
          ║   ┌──────────────────────────────────────────┐   ║
          ║   │  1. verify Merkle proof   ── passes ✓    │   ║  (stateless math)
          ║   │  2. transfer to player    ── fires  ✓    │   ║  (every iteration)
          ║   │  3. _setClaimed?          ── skipped ✗   │   ║  (waits for flush)
          ║   └──────────────────────────────────────────┘   ║
          ╚══════════════════════════════════════════════════╝
                                     │
                                     ▼
          ╔══════════════════════════════════════════════════╗
          ║           Flush points (bookkeeping):            ║
          ║                                                  ║
          ║   ▸ Token changes DVT → WETH  (mid-loop)         ║
          ║        └─→ _setClaimed for DVT  ── fires once    ║
          ║                                                  ║
          ║   ▸ Last iteration                               ║
          ║        └─→ _setClaimed for WETH ── fires once    ║
          ╚══════════════════════════════════════════════════╝
                                     │
                                     ▼
                    ┌─────────────────────────────────────┐
                    │           OUTCOME per token         │
                    │  payouts received : N (or M)        │
                    │  bitmap entries   : 1               │
                    │  remaining pot    : dust only       │
                    └─────────────────────────────────────┘
                                     │
                                     ▼
                    ┌─────────────────────────────────────┐
                    │  Transfer player balance → recovery │
                    └─────────────────────────────────────┘
​`
