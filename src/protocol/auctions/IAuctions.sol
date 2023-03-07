// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../types/Property.sol";

interface IAuctions {

    // Bidder
    function bid(TokenId tokenId, uint propertyValue, uint downPayment) external;
    function cancelBid(TokenId tokenId, Idx bidIdx) external;

    // Seller
    function loanBidActionable(Bid memory bid) external view returns(bool);
    function acceptBid(TokenId tokenId, Idx bidIdx) external;
}