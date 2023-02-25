// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ILending {

    event Deposit(address depositor, uint usdc, uint tusdc, uint time);
    event Withdrawal(address withdrawer, uint usdc, uint tusdc, uint time);

    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;  
}
