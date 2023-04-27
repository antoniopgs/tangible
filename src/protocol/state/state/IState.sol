// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/UD60x18.sol";

type TokenId is uint;
type Idx is uint;

interface IState {

    // Enums
    enum Status { None, Mortgage, Default, Foreclosurable }

    // Structs
    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
    }

    struct Loan {
        address borrower;
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    // Views
    function availableLiquidity() external view returns(uint);
    function status(uint tokenId) external view returns (Status); // Note: for testing
    function bids(uint tokenId) external view returns (Bid[] memory); // Note: for testing
}
