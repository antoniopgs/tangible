// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IBorrowing {

    // Functions
    function startLoan(TokenId tokenId, uint propertyValue, uint downPayment, address borrower) external;
    function payLoan(TokenId tokenId) external;
    function redeemLoan(TokenId tokenId) external;
    function forecloseLoan(TokenId tokenId, uint salePrice) external;

    // Views
    function utilization() external view returns (UD60x18);
}