// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/status/IStatus.sol";

interface IAuctions is IStatus {

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external;
    function cancelBid(uint tokenId, uint biduint) external;

    // Seller
    function acceptBid(uint tokenId, uint biduint) external;
}