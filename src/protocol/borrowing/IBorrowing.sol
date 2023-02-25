// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IBorrowing {

    struct Loan {
        address borrower;
        UD60x18 balance;
        UD60x18 installment;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }
    
    event NewLoan(uint tokenId, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller, uint time);
    event LoanPayment(uint tokenId, address payer, uint time, bool finalPayment);

    function startLoan(uint tokenId, uint propertyValue, uint principal, address borrower) external;
    function payLoan(uint tokenId) external;
    function maxLtv() external view returns (uint);
}
