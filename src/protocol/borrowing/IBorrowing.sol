// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing {

    // Events
    event NewLoan(TokenId tokenId, uint propertyValue, uint principal, address borrower, uint time);
    event LoanPayment(TokenId tokenId, address payer, uint time, bool finalPayment);

    function adminStartLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external;
    function acceptBidStartLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external;
    function payLoan(TokenId tokenId) external;
    function redeemLoan(TokenId tokenId) external;
}
