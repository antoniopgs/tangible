// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IMortgageBase {

    struct Loan {
        address borrower;
        UD60x18 balance;
        UD60x18 monthlyPayment;
        uint nextPaymentDeadline;
    }
}