// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Interest2Slopes {

    // Deployer inputs needed in storage
    uint private /* immutable */ baseYearlyRate;
    uint private /* immutable */ optimalUtilization;

    // Math constants
    uint private /* immutable */ m1;
    uint private /* immutable */ m2;
    uint private /* immutable */ b2;

    constructor(
        uint _baseYearlyRate,
        uint _optimalUtilization,
        uint optimalUtilizationYearlyRate,
        uint maxYearlyRate
    ) {
        // Store needed inputs
        baseYearlyRate = _baseYearlyRate;
        optimalUtilization = _optimalUtilization;

        // Calculate math constants
        m1 = (optimalUtilizationYearlyRate - baseYearlyRate) / optimalUtilization;
        b2 = (optimalUtilization * maxYearlyRate - optimalUtilizationYearlyRate) / (optimalUtilization - 1);
        m2 = maxYearlyRate - b2;
    }

    function slope1(uint x) private view returns(uint) {
        return m1 * x + baseYearlyRate;
    }

    function slope2(uint x) private view returns(uint) {
        return m2 * x + b2;
    }

    function calculateNewRate(uint utilization) private view returns(uint) {

        if (utilization <= optimalUtilization) {
            return slope1(utilization);

        } else {
            return slope2(utilization);
        }
    }

    function calculateNewRatePerSecond(uint utilization) external view returns(uint) {
        return calculateNewRate(utilization) / yearSeconds;
    }
}