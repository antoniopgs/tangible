// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IAuctions {

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint loanMonths) external;
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) external;
    function cancelBid(uint tokenId, uint idx) external;

    // Seller
    function acceptBid(uint tokenId, uint idx) external;
}