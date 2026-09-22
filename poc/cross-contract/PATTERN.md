# [Cross-Contract Reentrancy]

## Mental model

The attacker uses a callback to jump into another contract while the first contract is still updating its state. The second contract reads that old state and does something it shouldn't.

## Red-flag pattern

```solidity
// Vault
function withdraw() {
    uint256 amount = balances[msg.sender];
    (bool ok, ) = msg.sender.call{value: amount}("");   // triggers receive()
    balances[msg.sender] = 0;
}

// Rewards (separate contract, reads Vault)
function claimReward() {
    uint256 amount = vault.balances(msg.sender);   // reads stale state
    pay(msg.sender, amount);
}
```

## Canonical case

Example: Rewards.sol reads the Vault's balance to decide how much to pay. The attacker starts a withdrawal from the Vault, and during the ETH callback calls claimReward(). Rewards sees the Vault's old balance and pays the attacker again.

## Hunt-checklist

When I see an external call, I check other contracts that use this contract's state. A reentrancy lock on one contract doesn't protect the others, so I ask: can another contract read the old state before it gets updated?
