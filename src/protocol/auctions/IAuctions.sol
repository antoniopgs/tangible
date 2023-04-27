// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IAuctions is IState {

    // Bidder
    function bid(TokenId tokenId, uint propertyValue, uint downPayment) external;
    function cancelBid(TokenId tokenId, Idx bidIdx) external;

    // Seller
    function acceptBid(TokenId tokenId, Idx bidIdx) external;
}