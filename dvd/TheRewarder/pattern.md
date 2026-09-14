# Vulnerability Pattern: Payout/Bookkeeping Frequency Mismatch

## Core Idea

> **Every time a loop pays out per iteration but bookkeeps per group, you have a potential Rewarder.**

Whenever a loop does something valuable (transfers, mints, grants access), ask:

1. What runs **every iteration**? (the "payout")
2. What runs **once, or less often**? (the "check" or "record")
3. Can I craft input where those frequencies diverge in my favor?

If payout runs N times and the check runs 1 time, and I control N through the input — I win.

---

## Red Flags to Watch For

### 1. Gas-optimized batch functions

Any function whose comments or structure advertise "batched for gas savings" deserves extra scrutiny. Gas optimizations often mean "we moved this check out of the loop."
**Ask:** What invariant did that check protect? Does moving it break the invariant?

### 2. Accumulators flushed later

Variables like `bitsSet`, `totalAmount`, `pendingRewards` that accumulate inside a loop and get written to storage only at the end. The gap between "accumulating" and "flushing" is where attackers live.
**Ask:** What if the accumulator overflows, underflows, or misrepresents what actually happened?

### 3. Stateless validation inside a stateful loop

Merkle proofs, signature verification, hash checks — these are pure math. They return the same answer every time for the same input. If a loop validates with one of these and _acts_ on the validation (transferring, minting), but the "have I done this already?" check lives elsewhere → duplicate submissions might slip through.

### 4. Two arrays that must stay in sync

When a function takes multiple arrays where one indexes into the other.
**Ask:** Can I mismatch them? Make one longer than the other? Make them lie about each other?

### 5. State updates conditional on "changes"

Patterns like `if (currentThing != previousThing)` — "only do the expensive thing when something changes." If I keep the thing from changing, the expensive thing never fires.

---

## Auditing Checklist for Any Loop

1. **List everything that runs per iteration.** Transfers, mints, external calls, event emissions.
2. **List everything that runs conditionally or at the end.** Storage writes, checks, invariant enforcement.
3. **Enumerate adversarial inputs.** 1000 identical entries? Empty array? One entry? Max length? Entries in weird order?
4. **For each adversarial input, does per-iteration behavior stay honest?** Or does the "end-of-loop" behavior fail to catch the abuse?
5. **Follow the money.** Where do tokens/value flow, and where does the accounting live? If they can drift apart, that's exploitable.

---

## Mental Shift

**Stop assuming the contract does what it looks like it does.**
Assume nothing. Trace what actually happens, iteration by iteration, and see if the guards fire when they should.

The gap between what code is _meant_ to do and what it _actually_ does — that's what a vulnerability is. Every exploit lives in that gap.

---

## The Three-Read Exercise

For every function you audit:

1. **First read:** What is this function trying to do?
2. **Second read:** If this ran in a weird order or with weird input, what breaks?
3. **Third read:** Is there a per-iteration action and a per-something-else check?

Do this on every function. Within a few dozen contracts, it becomes reflex.

---

## Where This Pattern Shows Up in the Wild

- **Airdrop claim contracts** — batched multi-claims (The Rewarder itself)
- **Batch NFT mints** — "mint N in one call" where per-user cap checks lag behind mint counts
- **Voting systems** — delegating votes; checkpoint updates that lag actual vote-weight changes
- **Reward-harvesting protocols** — compounding across multiple pools in one tx
- **Bridge messages** — batched message processing; nonce updates that don't fire per message

Same pattern every time: something valuable happens per iteration, some guard runs less often, attacker makes the arithmetic of the gap favor them.

---

## Case Study: The Rewarder (Damn Vulnerable DeFi v4)

- **Payout per iteration:** `token.transfer(msg.sender, inputClaim.amount)` runs every loop.
- **Bookkeeping per token group:** `_setClaimed` runs only when the token changes or on the last iteration.
- **Stateless validation:** `MerkleProof.verify` returns true every time for the same proof.
- **Bitmap can't represent count:** A bit is either 0 or 1 — no way to record "claimed N times."

**Exploit:** Submit an array of 1000 identical `Claim` structs. Get paid 1000 times. Bookkeeping records one claim.
