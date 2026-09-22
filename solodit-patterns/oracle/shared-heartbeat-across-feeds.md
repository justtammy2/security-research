# Shared heartbeat across multiple Chainlink feeds

**Pattern:** A contract reads multiple Chainlink feeds but staleness-checks them all against a single heartbeat variable, causing constant reverts on healthy data or acceptance of stale data.

**Sniff test:** Does this contract have multiple feeds with a single heartbeat variable?

**Code shape:** Two or more `latestRoundData()` calls with only one `uint256 public immutable heartbeatInterval`, used in multiple `require(block.timestamp - updatedAt <= heartbeat)` checks.

## Instances seen

- M-12 JOJO Exchange (Sherlock, May 2023) — chainlinkAdaptor with asset feed + USDC feed sharing heartbeatInterval
