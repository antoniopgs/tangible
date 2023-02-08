// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IAuctions {

    struct Bidder {
        address addr;
        uint bid;
    }

    struct Auction {
        address seller;
        Bidder highestBidder;
        uint optionPeriodEnd;
    }

    // Seller
    function startAuction(uint tokenId) external;
    function acceptBid(uint tokenId) external;

    // Borrower
    function bid(uint tokenId, uint newBid) external;
    function loanBid(uint tokenId, uint newBid) external;
}