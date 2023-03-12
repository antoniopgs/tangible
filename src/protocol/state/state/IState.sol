// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

type TokenId is uint;
type Idx is uint;

interface IState {

    enum State { None, Mortgage, Default } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
    }

    struct Loan {
        address borrower;
        UD60x18 balance;
        UD60x18 installment;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }
}
