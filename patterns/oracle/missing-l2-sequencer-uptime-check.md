**Pattern:** On L2s, the protocol uses a Chainlink price feed without checking the sequencer. If the sequencer goes down, the price can become stale and may be exploitable when the sequencer comes back.

**Sniff test:** Is this deployed on an L2, and does every `latestRoundData()` call have a sequencer uptime check and grace period?

**Code shape:** `.latestRoundData()` on a price feed with no `sequencerUptimeFeed` check on Arbitrum, Optimism, Base, Metis, or Scroll.
