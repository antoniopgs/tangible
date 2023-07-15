// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/status/IStatus.sol";

interface IBorrowing is IStatus {
    
    event StartLoan(
        address borrower,
        uint tokenId,
        uint principal,
        uint maxDurationMonths,
        UD60x18 ratePerSecond,
        uint maxDurationSeconds,
        UD60x18 paymentPerSecond,
        uint maxCost,
        uint timestamp
    );
    event PayLoan(address caller, uint tokenId, uint payment, uint interest, uint repayment, uint timestamp, bool paidOff);
    event RedeemLoan(address caller, uint tokenId, uint interest, uint defaulterDebt, uint redemptionFee, uint timestamp);

    // Functions
    function startLoan(
        address borrower,
        uint propertyId,
        uint principal,
        uint maxDurationMonths,
        uint propertyValue,
        uint downPayment
    ) external;
    function payLoan(uint tokenId, uint payment) external;
    function redeemLoan(uint tokenId) external;

    // Views
    function utilization() external view returns(UD60x18);
    // function principalCap(Loan memory loan, uint month) external pure returns(uint cap);
    // function status(uint tokenId) external view returns (Status);
}