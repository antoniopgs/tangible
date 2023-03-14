// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

type TokenId is uint;
type Idx is uint;

interface IState {

    event NewLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 principal, address borrower, uint time);

    enum State { None, Mortgage, Default } // Note: maybe switch to: enum NftOwner { Seller, Borrower, Protocol }

    struct Bid {
        address bidder;
        UD60x18 propertyValue;
        UD60x18 downPayment;
    }

    struct Loan {
        address borrower;
        UD60x18 balance;
        UD60x18 periodicRate;
        UD60x18 installment;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }
}
