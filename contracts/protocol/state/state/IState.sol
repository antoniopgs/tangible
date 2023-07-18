// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IState {

    // Enums
    enum Status { ResidentOwned, Mortgage, Default, Foreclosurable }

    struct Loan {
        address owner;
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        // uint maxUnpaidInterest;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }
}
