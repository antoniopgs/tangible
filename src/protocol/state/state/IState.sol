// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IState {

    enum State { None, Mortgage, Default } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

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
