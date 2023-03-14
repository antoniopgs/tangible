// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";

contract LendingTest is Test, DeployScript {

    constructor() {
        run(); // deploy
    }

    function testDeposit(uint usdc) external {

        // Deposit
        ILending(address(protocol)).deposit(usdc);
    }

    function testWithdraw(uint usdc) external {

        // Withdraw
        ILending(address(protocol)).withdraw(usdc);
    }
}
