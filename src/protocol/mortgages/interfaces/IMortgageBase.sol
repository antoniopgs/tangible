// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IMortgageBase {

    struct Loan {
        UD60x18 propertyValue;
        UD60x18 monthlyPayment;
        UD60x18 balance;
        address borrower;
        uint nextPaymentDeadline;
    }
}