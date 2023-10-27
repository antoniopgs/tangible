// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../state/state/State.sol";
import { yearSeconds } from "../../types/TimeConstants.sol";
import { powu } from "@prb/math/src/UD60x18.sol";

contract InterestCurve is IInterest, State {

    // Deployer inputs needed in storage
    UD60x18 private immutable baseYearlyRate;
    UD60x18 private immutable optimalUtilization;

    // Math constants
    UD60x18 private immutable k1;
    UD60x18 private immutable k2;

    constructor (
        UD60x18 _baseYearlyRate,
        UD60x18 _optimalUtilization
    ) {

        // Store needed inputs
        baseYearlyRate = _baseYearlyRate;
        optimalUtilization = _optimalUtilization;

        // Calculate math constants
        k2 = convert(uint(1)).sub(optimalUtilization).powu(2);
        k1 = baseYearlyRate.sub(k2);
    }

    function calculateNewRate(UD60x18 utilization) private view returns(UD60x18) {
        return k1.add(k2).div(convert(uint(1)).sub(utilization));
    }

    function calculateNewRatePerSecond(UD60x18 utilization) external view returns(UD60x18) {
        return calculateNewRate(utilization).div(convert(yearSeconds));
    }
}