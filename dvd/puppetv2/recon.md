# puppet v2 - recon (day 27, aug 24)

**what the protocol does**
puppet v2 is a lending pool. you deposit WETH, you borrow DVT. the catch: the WETH you deposit has to be worth 3× the DVT you're borrowing, priced off the current WETH/DVT reserves on uniswap v2.

**the rule that should always hold**
your WETH collateral, valued in WETH terms, has to be at least 3× the WETH value of the DVT you borrow. that's the invariant.

**where it breaks**
the "price" comes from live uniswap v2 reserves. so anyone who can push those reserves around can make the collateral requirement collapse.

**how it plays out in the code**

- `calculateDepositOfWETHRequired()` — the entry point. tells you how much WETH you owe.
- it calls `_getOracleQuote()`.
- `_getOracleQuote()` grabs the current WETH and DVT reserves from the uniswap v2 pair and does the ratio.
- that ratio × 3 = your required deposit.
- no TWAP. no averaging. just whatever the pool looks like right now.

**attack idea (parking it for tomorrow)**
dump my DVT into the pair to tank the DVT price. then borrow against the cheap oracle.

**what i start with**
20 ETH, 10,000 DVT. enough to push a small pool around.

**what the pool holds**
10 WETH, 100 DVT in reserves. small enough that my 10k DVT wrecks the ratio.

**fix**
don't use spot reserves as an oracle. use a TWAP, or an independent feed like chainlink. anything that a single tx can't move.

**v1 → v2 — what actually changed**

- the bug is the same. both read spot AMM reserves and call that a price.
- different AMM under the hood. v1 = uniswap v1 exchange (ETH only, one token per exchange). v2 = uniswap v2 pair (any two tokens, WETH here).
- v2 also imports `UniswapV2Library` which looks like an oracle helper. it isn't. it's a ratio calculator. no time-weighting, no manipulation protection. importing it from uniswap's repo doesn't make it safe.
- v1 pulls eth and token balances straight off the exchange to price things. v2 goes through `UniswapV2Library.quote()`, which under the hood is just `amount * reserveOut / reserveIn`. same spot-ratio math, wrapped in a helper.

**backlog**
feeds `patterns/oracle/spot-amm-price-manipulation.md` — puppet v1 + v2 both.
