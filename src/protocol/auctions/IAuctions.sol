// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IAuctions is IState {

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external;
    function cancelBid(uint tokenId, uint biduint) external;

    // Seller
    function acceptBid(uint tokenId, uint biduint) external;
}