// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";

interface ILending is State {

    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;
}