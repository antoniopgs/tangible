// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../state/state/State.sol";

contract Interest is IInterest, State {

    function calculatePeriodRate(UD60x18 /*utilization*/) external view returns (UD60x18) {

        // Return periodRate
        return periodRate;
    }
}
