// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "../src/BorrowingV3.sol";
import "../src/tUsdc.sol";

contract DeployScript is Script {
    
    // Deploy protocol
    BorrowingV3 borrowing = new BorrowingV3();

    // Build tUsdcDefaultOperators;
    address[] tUsdcDefaultOperators;
    tUsdcDefaultOperators[0] = address(borrowing);

    // Deploy tUSDC
    tUsdc tUSDC = new tUsdc();

    // Initialize protocol
    borrowing.initialize(tUSDC);
}
