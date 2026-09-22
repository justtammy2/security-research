# [Cross-Function Reentrancy]

## Mental model

The attacker re-enters a different function in the same contract while the first function is still updating state. The second function sees the old/incomplete state and uses it.

## Red-flag pattern

```solidity
function withdraw() {
    uint256 amount = balances[msg.sender];
    sendETH(msg.sender, amount);       // attacker gets control here
    balances[msg.sender] = 0;
}

function transfer(address to, uint256 amount) {
    require(balances[msg.sender] >= amount);   // reads stale balance
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

## Canonical case

Lendf.Me: supply() called transferFrom() before finishing its state update. The ERC-777 callback let the attacker re-enter withdraw() while the old balance was still there.

## Hunt-checklist

- When I see an external call, I check other functions that use the same state. If one function is protected but another isn't, the attacker may still re-enter through the unprotected one. The lock should protect the whole flow.
- See ./src/Vault.sol and ./src/Attacker.sol for a simple PoC.
