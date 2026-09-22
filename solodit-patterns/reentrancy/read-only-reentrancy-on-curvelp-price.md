# Read Only Reentrancy On Curve Lp Price

**Class:** read-only/view reentrancy

**Pattern:** A Curve LP pool function makes an external call before finishing its state update. During that call, another contract reads the pool's derived price (get_virtual_price or similar) and uses it for a decision — collateral valuation, liquidation threshold, payout, while the price is temporarily distorted. The attacker exploits the reading contract, not the pool itself.

**Why devs get this wrong:** They assume view functions are safe because they don't change state, forgetting that they can still read broken state and make important decisions from it.

**Sniff test:** “Can an external call happen before the pool finishes updating, and can another contract read that temporary state to calculate a price?”

**Code shape:**

```solidity
// Pool (Curve-like)
function remove_liquidity(uint256 lp) external {
    transfer_eth(msg.sender, ...);      // external call — callback fires here
    balances[ETH] -= ...;                // state update happens after
    balances[wstETH] -= ...;
}

function get_virtual_price() external view returns (uint256) {
    return (balances[ETH] + balances[wstETH]) * 1e18 / totalSupply;
    // reads the mid-update balances — returns wrong value during callback
}

// Consumer (RiskEngine-like, different contract)
function getCollateralValue(address user) external view {
    uint256 price = pool.get_virtual_price();   // trusts the pool
    // ... uses stale price for liquidation check
}
```

## Instances seen

- [Sentiment Update #2 — H-01](https://solodit.cyfrin.io/issues/h-1-h-01-wsteth-eth-curve-lp-token-price-can-be-manipulated-to-cause-unexpected-liquidations-sherlock-sentiment-sentiment-update-2-git) (Sherlock, Dec 1, 2022) — Curve's `remove_liquidity()` sends ETH before updating internal balances. Attacker re-enters during the ETH callback and calls Sentiment's `RiskEngine`, which reads Curve's `get_virtual_price()` for LP collateral valuation. The depressed price makes healthy positions appear undercollateralized and triggers unfair liquidations — attacker profits from liquidation premiums.

## Flinch trigger

External call in a pool/LP function + view function derived from that state + another contract uses it as an oracle = check for read-only reentrancy.
