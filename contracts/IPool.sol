// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IPool {
    
    event Deposit(address depositor, uint amount, uint tUsdcMint);
    event Withdraw(address withdrawer, uint amount, uint tUsdcBurn);

    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;
}