// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/ISetter.sol";
import "../state/State.sol";

contract Setter is ISetter, State {

    function updateMaxLtv(uint newMaxLtvPct) external onlyOwner {
        require(newMaxLtvPct <= 100, "invalid pct");
        _maxLtv = convert(newMaxLtvPct).div(convert(100));
    }

    function updateMaxLoanMonths(uint newMaxLoanMonths) external onlyOwner {
        _maxLoanMonths = newMaxLoanMonths;
    }
}