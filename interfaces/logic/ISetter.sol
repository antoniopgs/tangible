// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ISetter {
    function updateMaxLtv(uint newMaxLtvPct) external;
    function updateMaxLoanMonths(uint newMaxLoanMonths) external;
    function updateBaseSaleFeeSpread(uint newBaseSaleFeeSpreadPct) external;
    function updateRedemptionFeeSpread(uint newRedemptionFeeSpreadPct) external;
    function updateDefaultFeeSpread(uint newDefaultFeeSpreadPct) external;
}