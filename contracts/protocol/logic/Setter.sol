// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/ISetter.sol";
import "../state/state/State.sol";

contract Setter is ISetter, State {

    function updateOptimalUtilization(uint newOptimalUtilizationPct) external onlyRole(TANGIBLE) {
        require(newOptimalUtilizationPct <= 100, "invalid pct");
        _optimalUtilization = convert(newOptimalUtilizationPct).div(convert(100));
    }

    function updateMaxLtv(uint newMaxLtvPct) external onlyRole(TANGIBLE) {
        require(newMaxLtvPct <= 100, "invalid pct");
        _maxLtv = convert(newMaxLtvPct).div(convert(100));
    }

    function updateMaxLoanMonths(uint newMaxLoanMonths) external onlyRole(TANGIBLE) {
        _maxLoanMonths = newMaxLoanMonths;
    }

    function updateRedemptionWindow(uint _days) external onlyRole(TANGIBLE) {
        _redemptionWindow = _days * 1 days;
    }

    function updateBaseSaleFeeSpread(uint newBaseSaleFeeSpreadPct) external onlyRole(TANGIBLE) {
        require(newBaseSaleFeeSpreadPct <= 100, "invalid pct");
        _baseSaleFeeSpread = convert(newBaseSaleFeeSpreadPct).div(convert(100));
    }

    function updateInterestFeeSpread(uint newInterestFeeSpreadPct) external onlyRole(TANGIBLE) {
        require(newInterestFeeSpreadPct <= 100, "invalid pct");
        _interestFeeSpread = convert(newInterestFeeSpreadPct).div(convert(100));
    }

    function updateRedemptionFeeSpread(uint newRedemptionFeeSpreadPct) external onlyRole(TANGIBLE) {
        require(newRedemptionFeeSpreadPct <= 100, "invalid pct");
        _redemptionFeeSpread = convert(newRedemptionFeeSpreadPct).div(convert(100));
    }

    function updateDefaultFeeSpread(uint newDefaultFeeSpreadPct) external onlyRole(TANGIBLE) {
        require(newDefaultFeeSpreadPct <= 100, "invalid pct");
        _defaultFeeSpread = convert(newDefaultFeeSpreadPct).div(convert(100));
    }
}