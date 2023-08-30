// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ISetter {
    
    function updateOptimalUtilization(uint newOptimalUtilizationPct) external;
    function updateMaxLtv(uint newMaxLtvPct) external;
    function updateMaxLoanMonths(uint newMaxLoanMonths) external;
    function updateRedemptionWindow(uint _days) external;
    function updateM1(uint newM1) external;
    function updateB1(uint newB1) external;
    function updateM2(uint newM2) external;
    function updateBaseSaleFeeSpread(uint newBaseSaleFeeSpreadPct) external;
    function updateInterestFeeSpread(uint newInterestFeeSpreadPct) external;
    function updateRedemptionFeeSpread(uint newRedemptionFeeSpreadPct) external;
    function updateDefaultFeeSpread(uint newDefaultFeeSpreadPct) external;
}