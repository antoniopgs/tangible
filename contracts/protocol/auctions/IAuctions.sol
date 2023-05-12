// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/status/IStatus.sol";

interface IAuctions is IStatus {

    event NewBid(address bidder);
    event CancelBid(address bidder);
    event AcceptBid(address caller);

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external;
    function cancelBid(uint tokenId, uint bidIdx) external;

    // Seller
    function acceptBid(uint tokenId, uint bidIdx) external;
}