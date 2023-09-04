// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../lendingInfo/LendingInfo.sol";

import { console } from "forge-std/console.sol";

contract Lending is ILending, LendingInfo {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Update pool
        totalDeposits += usdc;
        
        // Calulate depositor tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        // Mint tUsdc to depositor
        tUSDC.defaultOperatorMint(msg.sender, _tUsdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }

    function withdraw(uint usdc) external {

        console.log(0);

        // Calulate withdrawer tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        console.log(1);

        // Burn withdrawer tUsdc
        tUSDC.operatorBurn(msg.sender, _tUsdc, "", "");

        console.log(2);

        // Update pool
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        console.log(3);

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);

        console.log(4);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }
}