# Manipulable Reserves for IL Calculation

**Pattern:** Using Manipulable Pool Reserves for IL. The protocol uses the pool's current reserves to calculate IL. An attacker can change those reserves temporarily, make the protocol think they lost more money than they really did, and get extra funds from the reserve.

**Why devs get this wrong:** They assume the pool's reserves are an honest reflection of the market price, without considering that a single actor with a flashloan can distort them in the same transaction that measures IL.

**Sniff test:** Does this contract read the pool's current reserves (or a value derived from them) to decide a payout or measurement, and can I manipulate those reserves in the same transaction?

**Code shape:** A withdraw/burn function calls \_burn(id, to) to fetch the current native and foreign amounts (amountNative and amountForeign), then uses them in VaderMath.calculateLoss() to decide the LP’s covered loss/payout. No stored snapshot or manipulation-resistant price source is used — the amounts are determined from the live pool state at the moment of the call.

## Instances seen

-- [H-06] VaderPoolV2 — Vader Protocol (Code4rena, Dec 2021) — LP flashloans one pool asset, unbalances reserves, calls burn to trigger inflated IL measurement, claims payout from reserve in VADER, then rebalances to restore the pool

## Flinch trigger

Why is this payout being calculated from the pool’s state right now? Can I change that state immediately before calling `burn()`?
