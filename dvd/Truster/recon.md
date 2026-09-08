# Truster - Recon day(day 36, sep 3)

**what the protocol says it does**
Truster is a lending pool that offerrs free flashloans of DVT tokens. Anyone can borrow any amount of DVT from the pool's 1,000,000 DVT reserve, as long as they repay it within the same transaction. No fee, no interest.

**the rule that should always hold**

- The pool's DVT can only leave through actions the pool itself initiates — no external caller should be able to move, or gain permission to move, the pool's tokens.
- Flashloans must be repaid within the same transaction (pool balance never decreases net).

**what i start with**
Nothing i.e 0 DVT. Just the ability to send one transaction from the player EOA.

**what the pool holds**
1,000,000 DVT. No ETH. Exposes `flashLoan` (no access control) and a public `token` reference.

**where it breaks**
Inside `flashLoan`, the pool runs `target.functionCall(data)` — but `target` and `data` come straight from the caller. That means the attacker gets to pick what the pool says and who it says it to, and the pool ends up making that call as itself.

The attacker points `target` at the DVT token and sets `data` to `approve(attacker, poolBalance)`. So the pool ends up telling the token: _"let this attacker spend all my DVT."_ The token believes it because the pool is the one asking.

The pool's repayment check only looks at balances, so it never notices the allowance was handed out. Right after the flashloan returns, the attacker just calls `transferFrom` and walks off with everything.

**attack idea**
Use `flashLoan`'s arbitrary `(target, data)` to make the pool call `approve` on the token, granting me an allowance over its full balance. Then `transferFrom` the funds to `recovery`. Wrap both in an attacker contract's constructor so deployment = one transaction.

**how it plays out in the code**

1. Attacker calls `flashLoan(0, attacker, address(token), data)` where `data = approve(attacker, poolBalance)`.
2. Pool transfers 0 tokens (nothing borrowed), then runs `token.functionCall(data)` as itself → token records the allowance.
3. Balance check passes (nothing left the pool), `flashLoan` returns.
4. Attacker calls `token.transferFrom(pool, recovery, poolBalance)` → pool drained.

All wrapped in the attacker contract's constructor, so deploying it = one transaction = full exploit.

**fix**
Stop letting the caller pick `target` and `data`. Instead, always call back into the borrower's own contract at a fixed function (like `executeOperation`). That way the pool's identity only ever ends up in the borrower's hands, never pointed at the token.
