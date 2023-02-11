// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IMortgageBase {

    enum Status { Unowned, Auction, Mortgage, Foreclosed }

    struct Loan {
        address borrower;
        UD60x18 propertyValue;
        UD60x18 monthlyPayment;
        UD60x18 balance;
        uint nextPaymentDeadline;
    }
}