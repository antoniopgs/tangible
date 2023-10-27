// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../lendingInfo/LendingInfo.sol";

contract Lending is ILending, LendingInfo {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Calulate depositor tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        // Update pool
        _totalDeposits += usdc; // Note: must come after _usdcToTUsdc()

        // Mint tUsdc to depositor
        tUSDC.mint(msg.sender, _tUsdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }

    function withdraw(uint usdc) external {

        // Calulate withdrawer tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        // Burn withdrawer tUsdc
        tUSDC.burn(msg.sender, _tUsdc);

        // Update pool
        _totalDeposits -= usdc; // Note: must come after _usdcToTUsdc()
        require(_totalPrincipal <= _totalDeposits, "utilization can't exceed 100%");

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);

        emit Withdraw(msg.sender, usdc, _tUsdc);
    }
}