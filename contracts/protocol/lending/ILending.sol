// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ILending {

    event Deposit();
    event Withdraw();

    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;
}