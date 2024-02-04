// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import { Test } from "forge-std/Test.sol";

// Other
import { Handler } from "./Handler.t.sol";

contract Invariant is Test {

    Handler handler;

    function setUp() external {

        // Target handler contract
        targetContract(address(handler));
    }

    function invariant_foo() external {

    }

    function invariant_bar() external {

    }
}