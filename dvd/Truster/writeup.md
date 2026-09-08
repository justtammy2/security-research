# Truster — arbitrary external call with pool as msg.sender / flashloan callback hijack

## the invariant that should hold

The pool's DVT should only move when the pool itself decides to move it. No outsider should be able to take the pool's tokens, or gain permission to take them, without the pool's consent.

## why it breaks

`flashLoan` lets the caller pick both `target` (what to call) and `data` (what to say). Then it runs that call as the pool. That gives any caller the pool's identity for one arbitrary call — enough to make the pool approve them on the token. The repayment check only compares balances, so an allowance handed out this way slips right through.

## the attack

Call `flashLoan(0, self, token, data)` where `data` encodes `approve(attacker, poolBalance)`. The pool runs the approve as itself → attacker now has spending rights over the pool's full balance. Immediately call `transferFrom(pool, recovery, poolBalance)` to drain it. Both steps live in the attacker contract's constructor, so deployment = one transaction = pool empty.

## impact

Full loss. Any attacker can drain the entire pool (1,000,000 DVT) in a single transaction, starting with zero capital. No preconditions beyond being able to send a transaction.

## fix

Drop the arbitrary `target` and `data`. Force the callback into the borrower's own contract at a fixed function via a typed interface — e.g. `IFlashLoanReceiver(borrower).executeOperation(amount, msg.sender, data)`. The pool's identity only ever ends up back at the borrower, doing the borrower's own logic. Attacker can't point it anywhere else.

## related patterns

- **Arbitrary external calls with privileged `msg.sender`** — any function that lets an untrusted caller pick `target` + `data` and runs the call as itself.
- **Unsafe `delegatecall`** — same shape, worse consequences (attacker runs code _inside_ your storage).
- **ERC20 approve race** — allowances being the go-to lever whenever an attacker can make a contract "say" something.
- **Balance-only invariant checks** — verifying `balanceAfter >= balanceBefore` while ignoring allowances, ownership, or role state.

## notes

- `nonReentrant` is present but doesn't help — this isn't reentrancy, it's abuse of the pool's identity.
- Borrowing `amount = 0` is enough. No tokens need to move for the attack to work; only the approval matters.
- Constructor pattern is the standard way to fit multi-step exploits into the "single transaction" constraint. Deploying a contract counts as one transaction, and its constructor runs atomically within it.
- Worth remembering: any time you see `target.call(data)` or `target.functionCall(data)` where `target` and `data` are caller-supplied, ask what the calling contract's `msg.sender` can do that the caller can't do on their own.
