// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IAuctions {

    struct Bid {
        address bidder;
        UD60x18 amount;
        bool loan;
    }

    struct Auction {
        address seller;
        Bid[] bids;
        uint optionPeriodEnd;
    }

    // Seller
    function startAuction(uint tokenId) external;
    function acceptBid(uint tokenId) external;

    // Borrower
    function bid(uint tokenId, uint newBid) external;
    function loanBid(uint tokenId, uint newBid) external;
}