// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        // CHECKS-EFFECTS-INTERACTIONS pattern is violated here

        // CHECKS
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Insufficient balance");

        // External call gives the attacker control - INTERACTION
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");

        // EFFECTS
        balances[msg.sender] = 0;
    }

    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
}
