// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";

contract Rewards {
    Vault public vault;
    mapping(address => bool) claimed;

    constructor(address _vault) {
        vault = Vault(_vault);
    }

    function claimReward() external {
        require(!claimed[msg.sender], "Reward already claimed");
        uint256 vaultBalance = vault.balances(msg.sender);
        require(vaultBalance > 0, "No balance in vault");
        claimed[msg.sender] = true;
        (bool ok, ) = msg.sender.call{value: vaultBalance}("");
        require(ok, "reward transfer failed");
    }

    receive() external payable {}
}
