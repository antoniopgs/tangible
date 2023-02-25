// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IAuctions {

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
    }

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint downPayment) external;
    function cancelBid(uint tokenId, uint bidIdx) external;

    // Seller
    function loanBidActionable(Bid memory bid) external view returns(bool);
    function acceptBid(uint tokenId, uint bidIdx) external;
}