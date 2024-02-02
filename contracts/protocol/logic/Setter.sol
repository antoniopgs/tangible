// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/ISetter.sol";
import "../state/State.sol";

contract Setter is ISetter, State {

    function updateOptimalUtilization(uint newOptimalUtilizationPct) external onlyOwner {
        require(newOptimalUtilizationPct <= 100, "invalid pct");
        _optimalUtilization = convert(newOptimalUtilizationPct).div(convert(100));
    }

    function updateMaxLtv(uint newMaxLtvPct) external onlyOwner {
        require(newMaxLtvPct <= 100, "invalid pct");
        _maxLtv = convert(newMaxLtvPct).div(convert(100));
    }

    function updateMaxLoanMonths(uint newMaxLoanMonths) external onlyOwner {
        _maxLoanMonths = newMaxLoanMonths;
    }

    function updateBaseSaleFeeSpread(uint newBaseSaleFeeSpreadPct) external onlyOwner {
        require(newBaseSaleFeeSpreadPct <= 100, "invalid pct");
        _baseSaleFeeSpread = convert(newBaseSaleFeeSpreadPct).div(convert(100));
    }

    function updateRedemptionFeeSpread(uint newRedemptionFeeSpreadPct) external onlyOwner {
        require(newRedemptionFeeSpreadPct <= 100, "invalid pct");
        _redemptionFeeSpread = convert(newRedemptionFeeSpreadPct).div(convert(100));
    }

    function updateDefaultFeeSpread(uint newDefaultFeeSpreadPct) external onlyOwner {
        require(newDefaultFeeSpreadPct <= 100, "invalid pct");
        _defaultFeeSpread = convert(newDefaultFeeSpreadPct).div(convert(100));
    }
}