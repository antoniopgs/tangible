// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

contract Test3 is Test, DeployScript {

    function test() external {
        
        // Depositor deposits 25k
        address depositor = makeAddr("depositor");
        deal(address(USDC), depositor, 25_000e18);
        vm.prank(depositor);
        USDC.approve(address(protocol), 25_000e18);
        vm.prank(depositor);
        ILending(protocol).deposit(25_000e18);

        // loan is confirmed by gsp

        console.log("status c:", uint(Status(protocol).status(0)));
        console.log("");

        uint monthSeconds = 365 days / 12;
        skip(monthSeconds);

        console.log("status d:", uint(Status(protocol).status(0)));
        console.log("");

        skip(monthSeconds / 2);

        console.log("status e:", uint(Status(protocol).status(0)));
        console.log("");

        skip(monthSeconds);

        console.log("status f:", uint(Status(protocol).status(0)));
        console.log("");
    }
}