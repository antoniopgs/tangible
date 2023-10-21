// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../../types/TimeConstants.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract InterestConstant is TimeConstants {

    UD60x18 constant ratePerSecond = convert(uint(6)).div(convert(uint(100))).div(convert(yearSeconds)); // Note: 6% APR

    function borrowerRatePerSecond(UD60x18 utilization) internal view returns(UD60x18) {
        return ratePerSecond;
    }
}