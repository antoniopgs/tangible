// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IForeclosures is IState {
    function adminForeclose(TokenId tokenId, uint salePrice) external;
    // function foreclose(TokenId tokenId) external;
    // function chainlinkForeclose(TokenId tokenId) external;
}