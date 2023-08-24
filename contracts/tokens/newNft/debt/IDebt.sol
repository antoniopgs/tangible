// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IDebt {

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

    // Todo: Add Events Later

    // Admin Functions
    function refinance(uint tokenId) external;
    function foreclose(uint tokenId) external;
    function updateOtherDebt(uint tokenId, string calldata motive) external;

    // User Functions
    function startNewMortgage(uint tokenId) external; // MUST WORK ON TRAANSFER
    function payMortgage(uint tokenId, uint payment) external;
    function redeemMortgage(uint tokenId) external;
}