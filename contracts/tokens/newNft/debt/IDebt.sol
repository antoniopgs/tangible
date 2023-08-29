// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IDebt {

    // Todo: Add Events Later
    event PayLoan(address caller, uint tokenId, uint payment, uint interest, uint repayment, uint timestamp, bool paidOff);
    event RedeemLoan(address caller, uint tokenId, uint interest, uint defaulterDebt, uint redemptionFee, uint timestamp);

    // Admin Functions
    function refinance(uint tokenId) external;
    function foreclose(uint tokenId) external;
    function updateOtherDebt(uint tokenId, string calldata motive) external;

    // User Functions
    function startNewMortgage(uint tokenId) external; // MUST WORK ON TRAANSFER
    function payMortgage(uint tokenId, uint payment) external;
    function redeemMortgage(uint tokenId) external;
}