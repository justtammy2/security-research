# SideEntrance — attack

## hypothesis

the pool checks if a flash loan got repaid by looking at its ETH balance before and after. it doesn't care where the ETH came from. deposit() takes ETH and credits your balance. so you can take the loan, deposit the borrowed ETH back into the pool, and the pool thinks you repaid — but you also now have a deposit worth the full loan. withdraw it and you've drained the pool.

## preconditions

- pool has ETH to lend
- flashLoan only checks pool balance to confirm repayment
- deposit works during the flash loan callback
- withdraw pays out your recorded balance with no other checks
- you can deploy a contract with an execute() function

## attack steps

1. deploy an attacker contract with execute() and receive()
2. call flashLoan for the pool's full balance
3. pool sends the ETH and calls your execute()
4. inside execute(), call deposit and send the borrowed ETH back
5. flashLoan check passes — balance is back
6. call withdraw — pool sends you the ETH you "deposited"
7. send it to the recovery address

## why each step works

- flashLoan sends ETH first and checks after. it trusts you to make it whole.
- the check only looks at total pool balance. it doesn't know who repaid or how.
- deposit is open during the callback. one call puts the ETH back and credits you.
- withdraw has no timing rules. once flashLoan returns, you can pull the ETH straight out.
- everything runs in one transaction, so no one can interrupt.

run: `forge test --mp test/side-entrance/SideEntrance.t.sol -vvv`

## summary

the pool has two ways ETH moves in and out — flash loans and deposits — and they share the same balance. flashLoan checks repayment by looking at that balance. deposit also affects the balance, but it does something extra: it credits you. so you use the flash loan's own ETH to deposit, the loan check passes, and you're left with a claim you can withdraw. pool drained in one tx.

lesson: if two functions touch the same balance and one runs inside the other's callback, checking the balance isn't enough. the pool needs to track how much each borrower owes and force them to repay through a specific function — not just leave the money in the contract.

## diagram

```
attacker                    pool
   |                          |
   |--- flashLoan(1000) ----->|  balanceBefore = 1000
   |<---- 1000 ETH -----------|  pool balance: 0
   |--- execute() ----------->|
   |                          |
   |--- deposit{1000}() ----->|  pool balance: 1000
   |                          |  balances[attacker] = 1000
   |<--- (return) ------------|  check passes
   |                          |
   |--- withdraw() ---------->|  pool balance: 0
   |<---- 1000 ETH -----------|  balances[attacker] = 0
   |                          |
   |--- transfer to recovery->|
```
