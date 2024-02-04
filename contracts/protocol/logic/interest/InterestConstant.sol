// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../../../../interfaces/logic/IInterest.sol";
import "../../state/State.sol";

contract InterestConstant is IInterest, State {

    UD60x18 immutable ratePerSecond = convert(uint(6)).div(convert(uint(100))).div(convert(SECONDS_IN_YEAR)); // Note: 6% APR

    function calculateNewRatePerSecond(UD60x18) external view returns(UD60x18) {
        return ratePerSecond;
    }
}