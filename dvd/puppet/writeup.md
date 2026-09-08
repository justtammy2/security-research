# Puppet — Spot Price Oracle Manipulation

## Broken invariant

Borrower collateral must be worth ≥ 2x borrowed DVT at true market value.

## Root cause

`PuppetPool._computeOraclePrice()` reads Uniswap V1 spot reserves
(`exchange.balance / token.balanceOf(exchange)`) as the price of DVT in ETH.
Spot AMM reserves are manipulable by anyone in a single transaction.

## Attack

1. approve uniswap to spend player's 1000 DVT
2. dump 1000 DVT into the V1 exchange (10 DVT / 10 ETH pool)
   → new state ~1010 DVT / 0.099 ETH
   → oracle now reports 1 DVT ≈ 0.000098 ETH
3. borrow 100,000 DVT from PuppetPool with ~20 ETH collateral
   (would need 200,000 ETH at true price)
4. send loot to recovery

## Impact

Full drain of lending pool. ~4000x return on starting capital.
Critical severity.

## Fix

Do not use spot AMM reserves as a price feed. Use:

- Chainlink or equivalent push oracle with freshness + sequencer checks
- Uniswap V2/V3 TWAP with sufficient window (mitigates single-block manipulation)
- Cap price movement per block

## Notes

- Test passes with a two-call structure because `vm.prank` doesn't bump nonces
  in foundry. A mainnet-realistic exploit requires ERC20Permit to fit into a
  single tx (nonce == 1 check would fail on-chain otherwise).
- Follow-up: rewrite with permit as a rep. Logged in backlog.

## Related patterns

- Solodit: search "spot price oracle manipulation" — dozens of findings
- Same class as: bZx (2020), Harvest Finance, Warp Finance, Inverse Finance
