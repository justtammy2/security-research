# puppet v2 — concept

## vuln class

Manipulation of a DEX spot price used as an oracle. Spot Price Oracle Manipulation

Oracle Price Manipulation /

## why it's a bug (one sentence)

The protocol trusts Uniswap V2's spot price as an oracle, but the attacker can manipulate the pair's reserves by trading against the pool.

## the assumption being broken

protocol assumes: Uniswap V2's current reserves accurately represent the real market price of DVT.
reality: An attacker can temporarily distort the reserves by dumping DVT into the low-liquidity pair, causing the oracle to report an artificially low DVT price.

## where you'd see this in the wild

### solodit search terms

Uniswap V2 spot price manipulation, AMM spot price oracle, DEX price manipulation, spot price used as oracle, oracle manipulation, Uniswap reserves oracle ###

### similar past findings

**same specific bug (spot AMM manipulation):**

- bZx (2020)
- Harvest Finance
- Warp Finance
- Inverse Finance
- solodit: "spot price oracle manipulation" — dozens

**same class (oracle failure), different mechanism:**

- my repo: missing-chainlink-freshness-checks.md (M-02 Dyad)
- my repo: expired-oracle-treated-as-valid.md
- my repo: missing-l2-sequencer-uptime-check.md
- my repo: shared-heartbeat-across-feeds.md

START

│
▼
20 ETH + 10,000 DVT
│
▼
Wrap 20 ETH → 20 WETH
│
▼
Uniswap V2:
10 WETH + 100 DVT
│
▼
Sell 10,000 DVT → WETH
│
▼
DVT reserve ↑
WETH reserve ↓
│
▼
DVT spot price ↓↓↓
│
▼
Puppet reads manipulated price
│
▼
Required WETH collateral ↓↓↓
│
▼
~29.5 WETH is enough to borrow
1,000,000 DVT
│
▼
Borrow 1,000,000 DVT
│
▼
Lending pool DVT balance = 0
│
▼
Send 1,000,000 DVT → recovery
│
▼
DONE
