# NaiveReceiver - Recon (day 35, sep 2)

**what the protocol says it does**
a flash loan pool. you borrow WETH, do something with it in one tx, pay it back plus a flat 1 WETH fee. also supports meta-transactions — users can sign requests off-chain and have a forwarder relay them, so they don't need ETH for gas.

**the rule that should always hold**

1. flash loan fees should only be paid by receivers that actually wanted the loan.
2. `_msgSender()` should return the _real_ authorizing user — not just whoever's address happens to sit at the end of the calldata.

**Where the rule breaks:**

1. the pool doesn't check who initiated the loan. it just calls the receiver's callback and yanks the fee. if the receiver doesn't defend itself, anyone can drain it 1 WETH at a time.
2. the pool trusts the forwarder blindly — "if the forwarder is calling me, the last 20 bytes of calldata is the real user." combined with `Multicall` (which uses `delegatecall`), an attacker can smuggle their own calldata into the pool while `msg.sender` still looks like the forwarder. so they can pin any address they want to the end.

**How the bug works in code:**

- `flashLoan()` — sends WETH to receiver, calls `receiver.onFlashLoan(msg.sender, ...)`, pulls back amount + fee, credits fee to `deposits[feeReceiver]`. never checks that the receiver consented.
- `FlashLoanReceiver.onFlashLoan()` — doesn't validate the `initiator` argument. accepts any loan, pays any fee.
- `_msgSender()` — if `msg.sender == trustedForwarder`, returns the last 20 bytes of calldata. otherwise, normal `msg.sender`.
- `withdraw()` — uses `_msgSender()` to decide whose deposit balance to drain. same spoof vector.
- `Multicall.multicall()` — inherited from OZ. loops through inner calls with `delegatecall`, which preserves `msg.sender` and lets the caller control `msg.data` for each inner call.
- `BasicForwarder` — verifies the outer request's signature. does NOT verify the inner multicall bytes (it can't — they're just an argument).

**Attack idea**
bundle 11 calls into one multicall, sent through the forwarder in a single tx:

- 10× `flashLoan(receiver, weth, 0, "")` → forces the naive receiver to pay 10 WETH in fees. that 10 WETH ends up in `deposits[feeReceiver]`, bringing it from 1000 to 1010.
- 1× `withdraw(1010 ether, recovery)` with `feeReceiver`'s address glued to the end of the calldata. pool's `_msgSender()` reads those bytes, thinks `feeReceiver` is authorizing, drains all 1010 to `recovery`.

**what i start with**
`player` account, no funds. can only send 1 tx (nonce ≤ 2).

**what the pool holds**
1000 WETH. plus 10 WETH stuck in the receiver. `feeReceiver` (= deployer) is credited with 1000 WETH internally.

**Fix shape**

- bug 1: receiver's `onFlashLoan` should `require(initiator == owner)`. also verify `msg.sender == pool` and `token == expected`.
- bug 2: don't inherit `Multicall` on a contract that trusts a forwarder for identity. these two features are individually safe but toxic together. OZ's actual fix: override `multicall` to reject calls when `msg.sender == trustedForwarder`.

**pattern notes**
two vulnerabilities that are each borderline-benign alone but chain into a full drain. this is the composition trap:

- ERC-3156 assumes receivers self-defend.
- ERC-2771 assumes forwarders verify signatures.
- multicall assumes the outer authorization covers the inner calls.
  each assumption is fine in isolation. put them together and the gaps overlap.

**backlog**

- feeds `patterns/composition/erc2771-multicall-sender-spoofing.md` — this exact bug was found in OZ's own contracts.
- feeds `patterns/flash-loan/receiver-must-validate-initiator.md`.
- reminder: whenever i see `_msgSender()` override + `Multicall` + delegatecall, look for spoofing.
