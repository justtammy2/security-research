Chainlink price feed — an on-chain contract Chainlink deploys that holds the current price of an asset (like ETH/USD). Your contract reads from it instead of fetching prices itself.

Feed address — the specific contract address of one price feed on one chain. ETH/USD on Arbitrum has a different address than ETH/USD on Ethereum.

Interface (Solidity) — a list of function signatures with no code. Tells the compiler "any contract at this address has these functions," so you can call them.

AggregatorV3Interface — Chainlink's official interface. Every Chainlink feed implements it. Import it, wrap a feed address in it, call its functions.

latestRoundData() — the main function on that interface. Returns 5 values; you almost always only care about answer (the price) and updatedAt (when it was last updated).

Round — one price update pushed on-chain by Chainlink's nodes. Feeds don't stream — they publish new rounds periodically.

Heartbeat — the max time Chainlink promises between rounds. If block.timestamp - updatedAt > heartbeat, the price is stale — don't trust it.
Heartbeat - how often the oracle is expected to refresh its price, even when the price hasn't moved enough to trigger a normal update.

Sequencer (on L2) — the single node that orders transactions on an L2 like Arbitrum or Optimism. If it goes down, no new transactions get processed.

Sequencer Uptime Feed — a special Chainlink feed on L2s that reports sequencer status instead of a price. Same interface as a price feed. answer == 0 means up, answer == 1 means down.

Grace period — the buffer after the sequencer restarts before you should trust prices again. Usually 1 hour. Without it, the first transactions after restart can exploit stale prices.
