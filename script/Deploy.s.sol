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

        // Fork (needed for tUSDC's ERC777 registration in the ERC1820 registry)
        vm.createSelectFork("https://mainnet.infura.io/v3/f36750d69d314e3695b7fe230bb781af");

        // Deploy protocol
        borrowing = new BorrowingV3();

        // Build tUsdcDefaultOperators;
        address[] memory tUsdcDefaultOperators = new address[](1);
        tUsdcDefaultOperators[0] = address(borrowing);

        console.log(1);

        // Deploy tUSDC
        tUSDC = new tUsdc(tUsdcDefaultOperators);
        
        console.log(2);

        // Initialize protocol
        borrowing.initialize(tUSDC);
    }
}
