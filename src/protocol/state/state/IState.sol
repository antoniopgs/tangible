// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IState {

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
    }

    struct Loan {
        address borrower;
        uint balance;
        uint installment;
        uint unpaidInterest;
        uint nextPaymentDeadline;
    }
}
