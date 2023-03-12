// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IBorrowing {
    
    event NewLoan(TokenId tokenId, uint propertyValue, uint principal, address borrower, address seller, uint time);
    event LoanPayment(TokenId tokenId, address payer, uint time, bool finalPayment);

    function startLoan(TokenId tokenId, uint propertyValue, uint principal, address borrower) external;
    function payLoan(TokenId tokenId) external;
    function maxLtv() external view returns (uint);
}
