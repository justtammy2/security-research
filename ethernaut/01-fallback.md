# Ethernaut Level 1: Fallback

## The contract

The `Fallback` contract has an owner who can withdraw all the balance.
Ownership is set in the constructor and transferred through two paths:

1. `contribute()` — if a contributor donates more than the current
   owner's contribution, they become the owner. But contributions are
   capped at less than 0.001 ether per call, and the owner started
   with 1000 ether of recorded contribution. Reaching that through
   `contribute()` alone is impossible in practice.

2. The `receive()` function — triggered when the contract is sent
   ETH with no calldata. It sets `owner = msg.sender` as long as the
   sender has made any prior contribution and sends more than 0.

## The vulnerability

The `receive()` function grants ownership on a plain ETH transfer,
gated only by the sender having contributed something — anything —
previously. There is no check that the sender's contribution is
meaningful, and no check that receiving ETH should transfer ownership
at all.

Ownership transfer should never be a side effect of receiving funds.
The two concerns are unrelated and combining them creates an attack
surface that shouldn't exist.

## Exploit

Three steps:

1. Call `contribute()` with any amount above 0 (e.g. 1 wei of ether).
   This registers `contributions[msg.sender] > 0`.
2. Send ETH directly to the contract address with no calldata. This
   triggers `receive()`, which sees the prior contribution and
   assigns ownership.
3. Call `withdraw()` as the new owner, draining the balance.

## Mitigation

The `receive()` function should not modify ownership. If the contract
needs to accept ETH, `receive()` should either revert or simply
accept the funds without state changes. Ownership transfer, if
supported, belongs in a dedicated function with explicit access
control and clear semantics — not as a side effect of a fallback.

More generally: any function that transfers privileges (ownership,
admin rights, roles) should be explicit, gated by clear checks, and
never triggered by generic entry points like `receive()` or
`fallback()`.

## What tripped me up

[Replace this with what actually happened when you solved it. Examples
of what belongs here: did you miss that `receive()` exists as a
separate function from `fallback()`? Did you try to attack
`contribute()` first before noticing the second path? Did you not
know how to send ETH with no calldata from the browser console?
Whatever the honest answer is, write it. This section is what makes
the writeup useful to future-you and what makes the repo feel real
rather than performative.]

## Pattern to remember

Any function that grants privileges as a side effect of another
action (receiving ETH, being called by a certain address, etc.) is a
red flag. When reading unfamiliar code, flag every function that
changes ownership, roles, or access — then check what triggers it.
If the trigger isn't an obvious "transferOwnership"-style call, look
harder.
