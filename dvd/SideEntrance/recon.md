# SideEntrance - Recon day(day 40, sep 7)

**what the protocol says it does**
SideEntrance is a lending pool. Anyone can deposit ETH and withdraw it at any time. It also offers free flash loans from the pooled ETH, which must be repaid in the same transaction.

**the rule that should always hold**

- Flashloans must be repaid within the same transaction.
- Pools ETH balance must be >= sum of all balances[user]. i.e The pool must always hold atleastenough ETH to cover every depositor's claim/deposit.

**what i start with**
I start with 1ETH in my balance.

**what the pool holds**
Pool has 1,000 ETH in balance.

**suspicion list (what looked off on first read)**

- deposit, withdraw, and flashloan all touch the same ETH reserve. The flashloans are funded from the same pool of ETH that depositors put in i.e they share the same balance

**where it breaks**
the flash loan repayment check verifies raw pool balance, not that the borrower actually paid back. deposit() is on the same contract and credits balances[msg.sender] when it receives ETH. an attacker can route the borrowed ETH back through deposit() — the pool's balance is restored (repayment check passes) but the attacker now has a balances entry equal to the loan and can withdraw it in a follow-up call.

**attack idea**

1. contract calls flashLoan(pool.balance) to flashloan the pool's entire balance which is 1000.
2. in execute() callback, call pool.deposit{value: msg.value}() to deposit the borrowed ETH back in the pool.
3. once flashLoan finishes, call withdraw() to pull the ETH out as a "depositor". note that you can only call withdraw if you are a depositor.
4. send the ETH to the recovery address.

**how it plays out in the code**

`flashLoan()` — lends ETH, then checks the pool's balance is back. doesn't care how.
`deposit()` — takes ETH and credits the sender's balance. called inside the callback, it puts the loan back _and_ gives the attacker a claim.
`withdraw()` — pays out the sender's balance. drains what the attacker just "deposited."

- sequence: flashLoan sends ETH out → deposit sends it back (check passes, attacker credited) → withdraw pulls it out.

**why the check fails (what a safe flash loan would do differently)**
side entrance checks repayment by comparing pool balance before and after the callback. any ETH arriving from anywhere passes the check — including ETH the attacker sent via deposit().

a safe flash loan would:

- track debt per borrower when the loan is issued (side entrance doesn't — no debt variable exists)
- require an explicit repay() call that decrements that debt (side entrance has no repay function)
- block deposit() (and any other balance-affecting function) from being called during an active flash loan — e.g. a reentrancy-style lock on the pool for the duration of the callback

**fix**

- track debt per borrower when the flash loan is issued
- add a repay() function that decrements that debt; verify debt is zero at the end instead of checking raw balance
- block deposit() (and any other balance-affecting function) from being called during an active flash loan — e.g. a reentrancy-style lock on the pool for the duration of the callback
