// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IState {

    enum Status { ResidentOwned, Mortgage, Default }

    struct Loan {
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint unpaidPrincipal;
        uint startTime;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    struct Debt {
        Loan loan;
        uint otherDebt;
    }

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
        uint loanMonths;
    }
}