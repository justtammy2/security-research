## title

[High] Flash loan repayment check based on raw pool balance allows full drain via deposit() re-entry during callback

## severity

**High.** Full loss of pooled ETH. No preconditions beyond deploying a contract with an execute() callback. Attack is atomic (single tx), permissionless, and leaves no recovery path.

## vulnerability details

`SideEntranceLenderPool.flashLoan()` verifies repayment with `address(this).balance >= balanceBefore`. It doesn't track per-borrower debt or require an explicit repay call. `deposit()` on the same contract is payable and credits `balances[msg.sender]`, and is not locked during the flash loan callback. This means ETH sent to the pool via `deposit()` during `execute()` simultaneously satisfies the flash loan's balance check _and_ creates a withdrawable claim for the caller. `withdraw()` has no timing restriction, so the claim can be cashed out in the same transaction.

## impact

An attacker drains 100% of pooled ETH in a single transaction. All depositor funds are permanently lost. Attack cost is gas only.

## proof of concept

See attack.md — PoC section. Runs green with `forge test --mp test/side-entrance/SideEntrance.t.sol -vvv`.

## recommended mitigation

- Track debt per borrower: `mapping(address => uint256) public debt;` set on flash loan issuance.
- Add a `repay()` function that decrements debt and require debt to be zero at end of `flashLoan()` instead of checking raw balance.
- Lock `deposit()` (and any balance-affecting function) during an active flash loan, e.g. with a reentrancy-style guard on the pool.
