# puppet v2 — spot price oracle manipulation

## the invariant that should hold

if you want to borrow DVT, your WETH collateral has to be worth at least 3x what you're borrowing — priced against a real, honest market rate.

## why it breaks

puppet v2 asks the uniswap v2 pair "what's DVT worth right now?" and uses the answer as its oracle. specifically, `_getOracleQuote()` grabs the current WETH and DVT reserves off the pair and does WETH_reserve / DVT_reserve.

problem: anyone with tokens can move those reserves around by swapping. the "oracle" is just a live snapshot of a pool i can push around.

## the attack

starting position: 20 ETH, 10,000 DVT. pool holds 10 WETH and 100 DVT.

1. approve the router to spend my 10,000 DVT
2. dump all 10,000 DVT into the WETH/DVT pair
   - reserves go from (10 WETH, 100 DVT) to roughly (0.099 WETH, 10,100 DVT)
   - the oracle now thinks 1 DVT = ~0.0000098 WETH. down from 0.1 WETH. that's ~10,000x cheaper.
3. wrap my remaining ETH into WETH
4. approve the puppet pool to pull WETH from me
5. borrow the entire pool balance — 1,000,000 DVT
   - required deposit at the collapsed price: 3 × 1M × 0.0000098 ≈ 29.4 WETH. i have just enough.
6. send the 1M DVT to the recovery address

## impact

whole lending pool drained. 1M DVT gone. critical.

## fix

don't use live pool reserves as a price feed. options:

- chainlink (or similar) with freshness checks
- uniswap v2 or v3 TWAP with a long enough window that a single tx can't move it
- deviation caps that reject prices moving too fast

## related patterns

**same specific bug (spot AMM manipulation):**

- bZx (2020), harvest finance, warp finance, inverse finance
- solodit: search "spot price oracle manipulation" — dozens of findings

**same class (oracle failure), different mechanism — in my repo:**

- patterns/oracle/missing-chainlink-freshness-checks.md
- patterns/oracle/expired-oracle-treated-as-valid.md
- patterns/oracle/missing-l2-sequencer-uptime-check.md
- patterns/oracle/shared-heartbeat-across-feeds.md

**feeds pattern file (backlog):**

- patterns/oracle/spot-amm-price-manipulation.md — v1 + v2 both

## notes

**v1 vs v2.**

- same bug class. both read spot AMM reserves and call that a price.
- different pool under the hood. v1 = uniswap v1 exchange (ETH-only, one token per exchange). v2 = uniswap v2 pair (WETH-paired, any pair).
- v1 reads ETH and token balances straight off the exchange. v2 wraps the same spot-ratio math inside `UniswapV2Library.quote()` — same math, just hidden behind a helper. no time-weighting, no protection.
- the library import _looks_ like an oracle helper because it's from uniswap's repo. it isn't. it's a ratio calculator.

**foundry vs mainnet.**

the POC uses an attacker contract, so approve → swap → wrap → borrow → transfer all run in one tx. that's how the real exploits worked on mainnet — bZx, harvest, warp, inverse all ran through attacker contracts, often with flash loans layered on top for extra capital.

no mempool gap between the manipulation and the borrow. nothing for an arbitrageur or MEV bot to sandwich.

no permit rewrite follow-up needed here. v1 needed one because its two-call approve/swap flow didn't survive a real single-tx exploit setup. v2's approve → swap flow fits inside one attacker-contract call natively.
