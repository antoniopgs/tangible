// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IMortgageBase {

    struct Loan {
        string propertyCid;
        address borrower;
        UD60x18 balance;
        UD60x18 installment;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }
}