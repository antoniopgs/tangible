// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../state/state/State.sol";

contract InterestCurve is IInterest, State {

    // Time constants
    uint private constant yearSeconds = 365 days;

    // Deployer inputs needed in storage
    uint private /* immutable */ baseYearlyRate;
    uint private /* immutable */ optimalUtilization;

    // Math constants
    uint private /* immutable */ k1;
    uint private /* immutable */ k2;

    constructor (
        uint _baseYearlyRate,
        uint _optimalUtilization
    ) {

        // Store needed inputs
        baseYearlyRate = _baseYearlyRate;
        optimalUtilization = _optimalUtilization;

        // Calculate math constants
        k2 = (1 - optimalUtilization) ** 2;
        k1 = baseYearlyRate - k2;
    }

    function calculateNewRate(uint utilization) private view returns(uint) {
        return k1 + k2 / (1 - utilization);
    }

    function calculateNewRatePerSecond(uint utilization) external view returns(uint) {
        return calculateNewRate(utilization) / yearSeconds;
    }
}