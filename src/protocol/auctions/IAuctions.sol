// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../types/Property.sol";

type bidIdx is uint;

interface IAuctions {

    // Bidder
    function bid(tokenId _tokenId, uint propertyValue, uint downPayment) external;
    function cancelBid(tokenId _tokenId, bidIdx _bidIdx) external;

    // Seller
    function loanBidActionable(Bid memory bid) external view returns(bool);
    function acceptBid(tokenId _tokenId, bidIdx _bidIdx) external;
}