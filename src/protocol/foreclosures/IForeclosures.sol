// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/IState.sol";

interface IForeclosures is IState {
    function foreclose(TokenId tokenId) external;
}