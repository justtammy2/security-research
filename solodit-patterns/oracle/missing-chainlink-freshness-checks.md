# Missing Chainlink freshness checks

**Pattern:** Consumer contract calls `latestRoundData()` and uses the returned `price` without fully validating the response. Chainlink returns metadata (`timeStamp`, `answeredInRound`, `roundID`) so consumers can detect stale, incomplete, carried-over, or invalid data — the bug is throwing that metadata away.

**Sniff test:** For every `latestRoundData()` call, are all four checks present — `price > 0`, `timeStamp != 0`, `answeredInRound >= roundID`, and `block.timestamp - timeStamp <= threshold`?

**Code shape:** `.latestRoundData()` destructured with fields ignored (`( , int256 price, , , )`), or all fields destructured but never used in a `require`. Missing any of the four checks = finding.

**The four checks and what each catches:**

- `price > 0` — garbage or negative price (`price` is `int256`)
- `timeStamp != 0` — round started but never completed
- `answeredInRound >= roundID` — answer carried over from a previous round
- `block.timestamp - timeStamp <= threshold` — round completed but data too old

**Note:** the staleness threshold is per-feed based on the feed's heartbeat. See `shared-heartbeat-across-feeds.md`.

## Instances seen

- M-02 Dyad (Feb 2023) — `_getEthPrice()` shipped with zero freshness checks; fix added `timeStamp != 0` and `answeredInRound >= roundID` but still missed the staleness threshold and `price > 0`
