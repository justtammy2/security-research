# Reentering Debt Takeover During Repay

**Class:** cross-function reentrancy

**Pattern:** A liquidation/repay function makes an external call (typically a token transfer or callback) before it finishes clearing the borrower's position state. During that call, the attacker re-enters a sibling function like takeOverDebt that reads the still-active position and processes it as if it were untouched — letting the same debt be taken over, repaid, or liquidated twice
The function makes an external call before it finishes updating/clearing an important state. During that call, the attacker can enter another function that uses the same state and process it again.

**Why devs get this wrong:** They add nonReentrant to the risky-looking function (repay) and assume the state it touches is safe. But the modifier is a per-function lock, not a contract-wide one — a sibling function that mutates the same state has its own independent lock (or none), and the attacker enters through it instead.

**Sniff test:** “Before this function finishes updating the state, can an external call let me enter another function that uses the same state?”

**Code shape:**

```solidity
function repay() external nonReentrant {
// ... external call (transfer, callback) ...
// ↑ attacker re-enters here
delete positions[borrowingKey]; // state clear happens after
}

function takeOverDebt() external {
// reads positions[borrowingKey] — still populated during repay's callback
// processes the takeover against stale state
}
```

## Instance seen

- [Real Wagmi #2 — H-2](https://solodit.cyfrin.io/issues/h-2-adversary-can-reenter-takeoverdebt-during-liquidation-to-steal-vault-funds-sherlock-real-wagmi-2-git) (Sherlock, Oct 23, 2023) — `repay()` makes an external call before clearing the borrowing position. During that call, the attacker re-enters `takeOverDebt()` and processes the same `borrowingKey` again. `repay()` has `nonReentrant`, but `takeOverDebt()` doesn't — so the attacker enters through the unprotected sibling.

## Flinch trigger

External call + state still active + sibling function reads it = check for cross-function reentrancy.
