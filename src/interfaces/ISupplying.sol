// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ISupplying {

    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;  
}