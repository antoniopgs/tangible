// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IBorrowing {
    
    event StartLoan(
        address borrower,
        uint tokenId,
        uint principal,
        uint maxDurationMonths,
        UD60x18 ratePerSecond,
        uint maxDurationSeconds,
        UD60x18 paymentPerSecond,
        // uint maxCost,
        uint timestamp
    );
    event PayLoan(address caller, uint tokenId, uint payment, uint interest, uint repayment, uint timestamp, bool paidOff);
    event RedeemLoan(address caller, uint tokenId, uint interest, uint defaulterDebt, uint redemptionFee, uint timestamp);

    // Functions
    function startNewLoan(
        address buyer,
        uint tokenId,
        uint propertyValue,
        uint downPayment,
        uint maxDurationMonths
    ) external;
    function payLoan(uint tokenId, uint payment) external;
    function redeemLoan(uint tokenId) external;

    // Views
    function utilization() external view returns(UD60x18);
}