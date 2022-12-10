// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IAuctions {

    struct Bidder {
        address addr;
        uint bid;
    }

    struct Auction {
        address seller;
        uint buyoutPrice;
        Bidder highestBidder;
    }

    function startAuction(uint tokenId, uint buyoutPrice) external;
    function buyout(uint tokenId) external;
    function loanBuyout(uint tokenId) external;
    function bid(uint tokenId, uint newBid) external;
    function loanBid(uint tokenId, uint newBid) external;
    function acceptBid(uint tokenId) external;
}