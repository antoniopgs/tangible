// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "../src/BorrowingV3.sol";
import "../src/tUsdc.sol";

contract DeployScript is Script {

    BorrowingV3 borrowing;
    tUsdc tUSDC;

    constructor() {

        // Deploy protocol
        borrowing = new BorrowingV3();

        // Build tUsdcDefaultOperators;
        address[] memory tUsdcDefaultOperators;
        tUsdcDefaultOperators[0] = address(borrowing);

        // Deploy tUSDC
        tUSDC = new tUsdc(tUsdcDefaultOperators);

        // Initialize protocol
        borrowing.initialize(tUSDC);

    }
}
