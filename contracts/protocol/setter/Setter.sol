// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ISetter.sol";
import "../state/state/State.sol";

contract Setter is ISetter, State {

    function updateMaxLtv(uint newMaxLtvPct) external onlyRole(TANGIBLE) {
        require(newMaxLtvPct <= 100, "invalid pct");
        maxLtv = convert(newMaxLtvPct).div(convert(100));
    }

    function updateMaxLoanMonths(uint newMaxLoanMonths) external onlyRole(TANGIBLE) {
        maxLoanMonths = newMaxLoanMonths;
    }
}