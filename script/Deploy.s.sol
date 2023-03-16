// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "../src/BorrowingV2.sol";

contract DeployScript is Script {

    BorrowingV2 borrowing;

    function run() public {

        // Deploy borrowing
        borrowing = new BorrowingV2();
    }
}
