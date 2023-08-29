// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ISetter {

    function updateMaxLtv(uint newMaxLtvPct) external;
    function updateMaxLoanMonths(uint newMaxLoanMonths) external;
}