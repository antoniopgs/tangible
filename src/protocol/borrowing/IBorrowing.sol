// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing {
    
    event NewLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 principal, address borrower, uint time);
    event LoanPayment(TokenId tokenId, address payer, uint time, bool finalPayment);

    function startLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 downPayment, address borrower) external;
    function payLoan(TokenId tokenId) external;
}
