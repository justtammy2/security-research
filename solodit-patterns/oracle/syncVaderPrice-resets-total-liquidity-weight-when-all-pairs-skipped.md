# syncVaderPrice can zero out total liquidity weight and break price calculations

**Pattern:** The function loses existing liquidity weights when pairs are skipped. It starts \_totalLiquidityWeight at 0 and only adds the weights of pairs that are ready to update. When a pair is skipped, its existing weight is not added to the new total.

**Why devs get this wrong:** They assume that if a pair does not need an update, they can skip it completely. But the pair's old weight is still needed when rebuilding the total.

**Sniff test:** Does the function start a total at 0 and skip some entries? If yes, check whether the skipped entries' old values are still included in the total.

**Code shape:** syncVaderPrice() starts \_totalLiquidityWeight at 0. If a pair's update period has not passed, continue skips it. Its old liquidity weight is never added to \_totalLiquidityWeight. If all pairs are skipped, the total stays 0 and replaces the previous total.

## Instance seen

syncVaderPrice() — Vader Protocol — Calling syncVaderPrice() twice in the same block causes all pairs to be skipped on the second call. \_totalLiquidityWeight stays 0, so totalLiquidityWeight[Paths.VADER] is set to 0. Later, VADER price calculations divide by this value and revert.

## Flinch trigger

If I start a total at 0 and skip an entry, where does that entry's old value get added back?
