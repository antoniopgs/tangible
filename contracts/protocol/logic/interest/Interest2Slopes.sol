// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../../../../interfaces/logic/IInterest.sol";
import "../../state/state/State.sol";

contract Interest2Slopes is IInterest, State {

    UD60x18 immutable one = convert(uint(1));

    // Deployer inputs needed in storage
    UD60x18 private immutable baseYearlyRate;
    UD60x18 private immutable optimalUtilization;

    // Math constants
    UD60x18 private immutable m1;
    UD60x18 private immutable m2;
    UD60x18 private immutable b2;

    constructor(
        UD60x18 _baseYearlyRate,
        UD60x18 _optimalUtilization,
        UD60x18 optimalUtilizationYearlyRate,
        UD60x18 maxYearlyRate
    ) {
        // Store needed inputs
        baseYearlyRate = _baseYearlyRate;
        optimalUtilization = _optimalUtilization;

        // Calculate math constants
        m1 = (optimalUtilizationYearlyRate - baseYearlyRate) / optimalUtilization;
        b2 = optimalUtilization.mul(maxYearlyRate).sub(optimalUtilizationYearlyRate).div(optimalUtilization.sub(one));
        m2 = maxYearlyRate - b2;
    }

    function slope1(UD60x18 x) private view returns(UD60x18) {
        return m1.mul(x).add(baseYearlyRate);
    }

    function slope2(UD60x18 x) private view returns(UD60x18) {
        return m2.mul(x).add(b2);
    }

    function calculateNewRate(UD60x18 utilization) private view returns(UD60x18) {

        if (utilization <= optimalUtilization) {
            return slope1(utilization);

        } else {
            return slope2(utilization);
        }
    }

    function calculateNewRatePerSecond(UD60x18 utilization) external view returns(UD60x18) {
        return calculateNewRate(utilization).div(convert(SECONDS_IN_YEAR));
    }
}