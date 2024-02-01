// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface ILending {
    
    event Deposit(address depositor, uint amount, uint tUsdcMint);
    event Withdraw(address withdrawer, uint amount, uint tUsdcBurn);

    // Functions
    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;

    // Views
    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
}