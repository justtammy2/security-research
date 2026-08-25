# puppet v2 — attack

## hypothesis

I can swap my DVT for WETH to push the Uniswap price down, then use the lower price to borrow all the DVT from Puppet with my WETH.

## preconditions

- starting position: 20 ETH, 10,000 DVT
- pool state: 10 WETH, 100 DVT
- lending pool holds: 1,000,000 DVT

## attack steps (english first)

1. approve router to spend my DVT
2. swap ~10,000 DVT → WETH via router (dumps the DVT price)
3. now oracle sees collapsed price
4. call `borrow(all DVT in lending pool)` with the tiny WETH deposit required
5. done — i hold ~1M DVT + leftover WETH, well over the win condition

## why each step works

1. ERC20 approvals are standard for router interaction
2. constant product means my dump moves reserves to (~0.099, ~10,100), collapsing DVT/WETH ratio ~10,000×
3. `_getOracleQuote` reads live reserves — no TWAP, no protection
4. `calculateDepositOfWETHRequired` returns a tiny number, i deposit that, i borrow the pool empty
5. win condition: player DVT balance ≥ pool's DVT balance goal

## poc

[test code — coming]

## foundry-only vs mainnet-real

foundry test uses 3 separate player txs (approve, swap, borrow). works because
foundry has no mempool and no adversarial actors.

mainnet-realistic version needs a single-tx attacker contract:

## summary:

The attack manipulates the Uniswap V2 spot price that Puppet uses as its oracle. I start with 20 ETH and 10,000 DVT, sell my DVT into the WETH/DVT pool to make DVT appear much cheaper, then use the lower oracle price to borrow DVT with less WETH collateral. I can sell the borrowed DVT back into the pool to push the price even lower, allowing me to borrow progressively larger amounts until I can drain the pool's 1,000,000 DVT.

START
│
├── 20 ETH
├── 10,000 DVT
│
↓
Convert ETH → WETH
│
↓
Sell DVT → WETH on Uniswap V2
│
↓
DVT reserve ↑
WETH reserve ↓
│
↓
Oracle says DVT is cheaper
│
↓
Collateral requirement decreases
│
↓
Borrow DVT
│
↓
Sell borrowed DVT → WETH
│
↓
DVT reserve ↑↑
WETH reserve ↓↓
│
↓
Oracle says DVT is even cheaper
│
↓
Borrow MORE DVT
│
↓
Repeat
│
↓
Eventually borrow 1,000,000 DVT
│
↓
POOL DRAINED
