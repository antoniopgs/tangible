// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing {

    function adminStartLoan(uint tokenId, uint propertyValue, uint downPayment, address borrower) external;
    function acceptBidStartLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external;
    function payLoan(TokenId tokenId) external;
    function redeemLoan(TokenId tokenId) external;
}