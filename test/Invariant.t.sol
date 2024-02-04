// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { StdInvariant } from "lib/openzeppelin-contracts/lib/forge-std/src/StdInvariant.sol"; // Todo: fix foundry imports later
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

// Other
import { Handler } from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {

    Handler handler;

    function setUp() external {

        handler = new Handler();

        // Target handler contract
        targetContract(address(handler));
    }

    function invariant_foo() external {
        assertEq(handler.x(), 0);
    }
}