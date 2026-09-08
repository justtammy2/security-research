# oracle-price-manipulation-via-manipulable-pool-reserves

**Pattern:** Using Pool Reserves to Calculate a Price. The protocol uses the pool's current reserves to calculate the price of an LP token. An attacker can temporarily change those reserves with a large trade, causing the protocol to calculate the wrong price.

**Why devs get this wrong:** They assume the pool's reserves always show a fair price, forgetting that someone can temporarily change them.

**Sniff test:** Does the contract use the pool's current reserves to calculate a price? If yes, can I change those reserves right before the contract reads them?

**Code shape:** latestAnswer() gets the pool's current baseReserve and quoteReserve and uses them to calculate the LP token price. Because these are live reserves, an attacker can manipulate them before latestAnswer() is called.

## Instance seen

-- [H-04] MagicLpAggregator — Abracadabra Money — The attacker flashloans a huge amount of DAI, trades it into the pool, changes the reserves, and then calls latestAnswer(). The oracle sees the manipulated reserves and reports the LP token as worth about $67 instead of $2. The attacker then reverses the trade and repays the flash loan.

## Flinch trigger

Why is the contract trusting the pool's reserves right now? Can I change the reserves immediately before the contract reads them?
