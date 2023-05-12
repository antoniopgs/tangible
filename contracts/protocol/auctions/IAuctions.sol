// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/status/IStatus.sol";

interface IAuctions is IStatus {

    event NewBid(address bidder, uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths, UD60x18 ltv);
    event CancelBid(address bidder, uint tokenId, uint bidIdx);
    event AcceptBid(uint tokenId, uint bidIdx, Status status);

    // Bidder
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external;
    function cancelBid(uint tokenId, uint bidIdx) external;

    // Seller
    function acceptBid(uint tokenId, uint bidIdx) external;
}