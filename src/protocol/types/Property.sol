// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

type tokenId is uint;
type idx is uint;

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

struct Property {
    Bid[] bids;
    Loan loan;
}