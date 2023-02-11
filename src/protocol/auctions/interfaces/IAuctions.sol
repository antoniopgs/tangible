// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IAuctions {

    struct Bid {
        address bidder;
        UD60x18 propertyValue;
        UD60x18 downPayment;
    }

    struct Auction {
        address seller;
        Bid[] bids;
        uint optionPeriodEnd;
        uint optionPeriodBidIdx;
    }

    // Seller
    function startAuction(uint tokenId) external;
    function acceptBid(uint tokenId) external;

    // Borrower
    function bid(uint tokenId, UD60x18 propertyValue, UD60x18 downPayment) external;
}