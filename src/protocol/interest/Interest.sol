// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../state/state/State.sol";

import "forge-std/console.sol";

contract Interest is IInterest, State {

    function calculatePeriodRate(UD60x18 utilization) public view returns (UD60x18) {
        console.log("c1");

        // Return periodRate
        return periodRate;
    }
}
