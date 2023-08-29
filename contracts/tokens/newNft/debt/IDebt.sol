// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IDebt {

    // Todo: Add Events Later

    // Admin Functions
    function refinance(uint tokenId) external;
    function foreclose(uint tokenId) external;
    function updateOtherDebt(uint tokenId, string calldata motive) external;

    // User Functions
    function startNewMortgage(uint tokenId) external; // MUST WORK ON TRAANSFER
    function payMortgage(uint tokenId, uint payment) external;
    function redeemMortgage(uint tokenId) external;
}