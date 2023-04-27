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
        uint installment;
        UD60x18 periodicRate; // Note: might be same for every loan now, but might differ between loans later
        uint balance;
        uint unpaidInterest;
        uint nextPaymentDeadline;
    }

    // Views
    function status(uint tokenId) external view returns (Status); // Note: for testing
    function bids(uint tokenId) external view returns (Bid[] memory); // Note: for testing
    function availableLiquidity() external view returns(uint);
}
