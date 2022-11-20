// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract UtilsScript is Script {

    function warpTo(uint desiredTime) public {
        console.log("warping to %d\n", desiredTime);
        vm.warp(desiredTime);
    }

    function warpBy(uint desiredJump) public {
        console.log("warping by %d\n", desiredJump);
        vm.warp(block.timestamp + desiredJump);
    }

    function createUsers(uint amount) public returns(address[] memory users) {
        users = new address[](amount);
        for (uint i = 1; i <= amount; i++) { // Private key cannot be 0
            users[i - 1] = vm.addr(i);
        }
    }

    function max(uint a, uint b) public pure returns(uint) {
        return a >= b ? a : b;
    }
}
