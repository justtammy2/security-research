// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/Rewards.sol";
import "../src/Attacker.sol";

contract VaultTest is Test {
    Vault public vault;
    Rewards public rewards;
    Attacker public attacker;

    function setUp() public {
        // Deploy the Vault
        vault = new Vault();

        // Deploy Rewards and connect it to the Vault
        rewards = new Rewards(address(vault));

        // Fund the Rewards contract so it can pay rewards
        vm.deal(address(rewards), 1 ether);

        // Deploy the attacker with Vault + Rewards
        attacker = new Attacker(vault, rewards);

        // Give the attacker 1 ETH to deposit into the Vault
        vm.deal(address(this), 1 ether);
    }

    function testCrossContractReentrancy() public {
        // Attacker deposits 1 ETH and starts the attack
        attacker.attack{value: 1 ether};

        // Attacker should now have:
        // 1 ETH received back from Vault
        // 1 ETH received from Rewards
        assertEq(address(attacker).balance, 2 ether);

        // Rewards contract paid out the 1 ETH reward
        assertEq(address(rewards).balance, 0);

        // Vault's balance should be back to 0
        assertEq(address(vault).balance, 0);
    }
}
