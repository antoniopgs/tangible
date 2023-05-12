// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../state/status/IStatus.sol";

interface IBorrowing is IStatus {

    event StartLoan();
    event PayLoan();
    event RedeemLoan();

    // Functions
    function startLoan(address borrower, uint tokenId, uint principal, uint maxDurationMonths) external;
    function payLoan(uint tokenId, uint payment) external;
    function redeemLoan(uint tokenId) external;

    // Views
    function lenderApy() external view returns(UD60x18);
    // function principalCap(Loan memory loan, uint month) external pure returns(uint cap);
    // function status(uint tokenId) external view returns (Status);
    function utilization() external view returns(UD60x18);
}