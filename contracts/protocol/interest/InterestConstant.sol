// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../../types/TimeConstants.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

contract InterestConstant is IInterest {

    UD60x18 immutable ratePerSecond = convert(uint(6)).div(convert(uint(100))).div(convert(yearSeconds)); // Note: 6% APR

    function calculateNewRatePerSecond(UD60x18) external view returns(UD60x18) {
        return ratePerSecond;
    }
}