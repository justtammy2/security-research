# naive receiver — attack

## hypothesis

I can force the naive receiver to pay 10 flash loan fees, which lands 10 WETH into `deposits[feeReceiver]`. Then I can pretend to be `feeReceiver` and withdraw all 1010 WETH to `recovery`. All in one transaction, using multicall + the trusted forwarder.

## preconditions

- starting position: `player` account, 0 WETH, only 1 tx allowed (nonce ≤ 2)
- receiver holds: 10 WETH
- pool holds: 1000 WETH, credited to `deposits[deployer]`
- `feeReceiver == deployer` (same address, set in constructor)
- forwarder is permissionless — anyone can send requests through it (but must sign their own)

## attack steps (english first)

1. build 10 identical flash loan calls: `flashLoan(receiver, weth, 0, "")`
2. build 1 withdraw call: `withdraw(1010 ether, recovery)`, with `deployer`'s address glued to the end of the calldata
3. put all 11 into one `multicall([...])` payload
4. wrap that multicall in a forwarder request signed by `player`
5. send it via `forwarder.execute(request, signature)`
6. done — recovery has 1010 WETH, pool has 0, receiver has 0

## why each step works

1. **flash loan × 10** — the pool doesn't check who initiated the loan. the receiver doesn't check `initiator` in its callback. so anyone can force the receiver to eat a 1 WETH fee per loan. borrowing 0 costs nothing but still triggers the fee. 10 loans = 10 WETH moved from receiver into `deposits[feeReceiver]`.

2. **spoofed withdraw** — the pool's `_msgSender()` says "if the forwarder is calling, trust the last 20 bytes of calldata as the sender." by appending `deployer`'s address to the withdraw call's bytes, the pool thinks `deployer` (= `feeReceiver`) is authorizing. that account has 1010 WETH credited, so the drain succeeds. funds go to `recovery` because that's the second argument.

3. **multicall bundling** — the challenge only allows 1 tx from player. `multicall` runs all 11 calls inside a single function call. it uses `delegatecall`, which preserves `msg.sender` (the forwarder) for each inner call — that's what lets the spoofed sender trick work on the inner withdraw.

4. **forwarder request** — the forwarder only verifies the _outer_ request's signature. it doesn't inspect the inner multicall bytes. so my "honestly signed by player" outer request can carry attacker-crafted inner bytes.

5. **execute** — one call, one tx, everything runs in sequence: 10 loans first (to build the 1010 balance), then the withdraw.

## order matters

flash loans MUST come before the withdraw. if withdraw runs first, `deposits[feeReceiver]` is only 1000 → drain leaves 10 WETH stranded in the receiver → challenge fails.

## poc

[test code — coming]

## foundry-only vs mainnet-real

foundry test builds and signs the request inside the test using `vm.sign(playerPk, ...)`. on mainnet, `player` would sign off-chain (with wallet/EIP-712) and any relayer could submit — the exploit is transferable, no simulator tricks needed.

## summary:

The attack combines two bugs. First, the naive receiver doesn't check who requested each flash loan, so I can force it to pay 10 fees to nobody — draining its 10 WETH into the pool's internal ledger under `feeReceiver`'s name. Second, the pool's meta-transaction handling trusts whatever address sits at the end of its calldata when the forwarder is calling — and `Multicall` lets me smuggle attacker-crafted bytes into the pool while `msg.sender` still looks like the forwarder. I glue `feeReceiver`'s address onto a withdraw call, the pool drains the full 1010 WETH balance, and sends it to `recovery`. All 11 calls fit into one multicall wrapped in one signed forwarder request — one transaction, everything moves.

START
│
├── player (0 WETH, 1 tx allowed)
├── receiver (10 WETH, no initiator check)
├── pool (1000 WETH → credited to deployer)
├── deployer == feeReceiver
│
↓
Build 10 flashLoan(receiver, weth, 0, "") calls
│
↓
Build 1 withdraw(1010 ether, recovery) call
│
↓
Append feeReceiver's address to withdraw calldata
│
↓
Bundle all 11 into pool.multicall([...])
│
↓
Wrap multicall bytes in a BasicForwarder.Request
│
↓
Sign request as player, call forwarder.execute(...)
│
↓
── inside the tx ──
│
↓
Forwarder calls pool.multicall(...) with player appended
│
↓
Multicall delegatecalls each inner action
│
↓
Loop 10× : flashLoan drains 1 WETH from receiver → deposits[feeReceiver] += 1
│
↓
deposits[feeReceiver] = 1000 + 10 = 1010
receiver balance = 0
│
↓
Withdraw runs: \_msgSender() reads last 20 bytes → returns feeReceiver
│
↓
deposits[feeReceiver] -= 1010
weth.transfer(recovery, 1010)
│
↓
POOL DRAINED, RECEIVER DRAINED, RECOVERY = 1010 WETH
