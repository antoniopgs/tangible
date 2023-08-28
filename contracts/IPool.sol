// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IPool {
    
    event Deposit(address depositor, uint amount, uint tUsdcMint);
    event Withdraw(address withdrawer, uint amount, uint tUsdcBurn);

    // Functions
    function deposit(uint usdc) external;
    function withdraw(uint usdc) external;

    // Views
    function availableLiquidity() external view returns(uint);
    function utilization() external view returns(UD60x18);
    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount);
    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount);
    // function borrowerApr() external view returns(UD60x18 apr);
}