# naive receiver — trusted forwarder + multicall sender spoofing

## the invariant that should hold

1. flash loan fees should only be paid by receivers that actually asked for the loan.
2. `_msgSender()` should return the real authorizing user — not just whatever address happens to sit at the end of the calldata.

## why they break

**invariant 1.** the pool's `flashLoan()` doesn't check who requested the loan. it sends WETH to the receiver, calls its callback, then pulls back amount + fee. the receiver is supposed to defend itself by checking `initiator` in `onFlashLoan()` — but the naive receiver here doesn't. so anyone can call `flashLoan(naiveReceiver, ...)` and force the receiver to eat the 1 WETH fee.

**invariant 2.** the pool's `_msgSender()` says: "if the caller is the trusted forwarder, the real user is glued to the last 20 bytes of calldata." this trust is fine when the forwarder controls what gets appended. it breaks when an attacker can smuggle their own calldata into the pool while `msg.sender` is still the forwarder — and `Multicall` (which uses `delegatecall`) does exactly that. the pool can't tell "forwarder appended this after verifying a signature" from "attacker wrote raw bytes that end with this address."

## the attack

starting position: `player` with 0 WETH, only 1 tx allowed. receiver holds 10 WETH. pool holds 1000 WETH credited to `deposits[deployer]`. `deployer == feeReceiver`.

everything happens inside one signed forwarder request.

1. build 10 identical calls: `flashLoan(receiver, weth, 0, "")`
   - each one forces the receiver to pay 1 WETH in fees. that WETH gets credited to `deposits[feeReceiver]`. after 10 calls, `deposits[feeReceiver]` = 1000 + 10 = 1010. receiver = 0.
2. build 1 call: `withdraw(1010 ether, recovery)` — but append `deployer`'s address as the last 20 bytes of the calldata.
   - when the pool's `_msgSender()` runs, it sees the forwarder as caller and reads the appended address. thinks `deployer` (= `feeReceiver`) is authorizing.
3. bundle all 11 into one `multicall([...])` payload
   - multicall uses `delegatecall`, which preserves `msg.sender` as the forwarder for each inner call. that's what makes the spoof work on the inner withdraw.
4. wrap the multicall bytes in a `BasicForwarder.Request`, sign as `player`, send via `forwarder.execute(request, signature)`
   - the forwarder verifies the outer request's signature (player signed it, honest). it does not inspect the inner multicall bytes — it can't, they're just an argument.
5. pool drains all 1010 WETH to `recovery`

## impact

full drain of the pool (1000 WETH) and the receiver (10 WETH). one signed request, one transaction.

## fix

**bug 1 (receiver side).** `onFlashLoan()` needs to validate what it's being told:

```solidity
require(msg.sender == address(pool), "unauthorized pool");
require(initiator == owner, "unauthorized initiator");
require(token == address(weth), "unexpected token");
```

standard ERC-3156 receiver hygiene. the naive one is missing all three, but the initiator check is the one that stops this exploit.

**bug 2 (pool side).** don't compose `Multicall` with a trusted-forwarder-based `_msgSender()` on the same contract. individually they're safe. together they're a spoofing primitive.

the actual openzeppelin fix (this exact bug was reported against their `ERC2771Context` + `Multicall` combo): override `multicall` to reject when `msg.sender == trustedForwarder`. meta-tx users can't hit multicall at all, closing the smuggling vector.

alternatives:

- require explicit signed authorization (EIP-712) for state-changing functions like `withdraw`, so identity isn't derived from `_msgSender()` alone
- separate multicall into a distinct contract that doesn't trust the forwarder

## related patterns

**same specific bug (ERC-2771 + Multicall sender spoofing):**

- openzeppelin advisory GHSA-wprv-93r4-jj2p (2023) — same primitive, reported against their own contracts
- multiple DVD-style challenges built around this pattern
- solidit: search "ERC2771" or "trusted forwarder" — recurring finding

**same class (misplaced trust in caller identity), different mechanism — in my repo:**

- patterns/access-control/tx-origin-vs-msg-sender.md
- patterns/access-control/signature-replay-across-chains.md
- patterns/access-control/permit-frontrunning.md

**feeds pattern files (backlog):**

- patterns/composition/erc2771-multicall-sender-spoofing.md
- patterns/flash-loan/receiver-must-validate-initiator.md

## notes

**the composition trap.** neither bug is catastrophic alone.

- bug 1 alone: drain the receiver's 10 WETH into the pool's internal ledger. money moves, but stays inside the pool. no theft.
- bug 2 alone: spoof `_msgSender()` on withdraw. but there's no big juicy balance to steal from — deployer's 1000 WETH is the target, and without bug 1 you can't add the receiver's 10 to that pile.

put them together and bug 1 consolidates the treasure while bug 2 unlocks it. this is the pattern to remember: individually-safe features become unsafe when they compose. audit surfaces aren't just per-function — they're across trust boundaries between features.

**why the forwarder isn't really the villain.** the forwarder does verify signatures on the outer request. it's not sloppy. the pool is the one making the too-broad assumption ("trust anything from the forwarder"). the forwarder just happens to be the vector that exposes the pool's mistake.

**why multicall is the vector.** delegatecall preserves `msg.sender` and lets caller-controlled `msg.data` reach functions that read `_msgSender()`. any batching primitive that uses delegatecall on a contract with meta-tx identity logic is suspect. multicall isn't special — it's just the most common one.

**foundry vs mainnet.** the POC signs with `vm.sign(playerPk, ...)` inside the test. on mainnet, `player` signs off-chain via wallet/EIP-712, and any relayer can submit `forwarder.execute(...)`. the exploit transfers cleanly — no simulator tricks. that's what makes it dangerous.

**nonce constraint.** the challenge caps player at 1 tx (nonce ≤ 2). this forces the multicall bundling. it's also realistic — a real attacker wants atomicity to avoid getting frontrun between the drain and the withdraw.
