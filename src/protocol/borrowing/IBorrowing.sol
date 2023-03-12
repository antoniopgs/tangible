// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing {
    
    event NewLoan(TokenId tokenId, uint propertyValue, uint principal, address borrower, address seller, uint time);
    event LoanPayment(TokenId tokenId, address payer, uint time, bool finalPayment);

    function startLoan(TokenId tokenId, uint propertyValue, uint principal, address borrower) external;
    function payLoan(TokenId tokenId) external;
}
