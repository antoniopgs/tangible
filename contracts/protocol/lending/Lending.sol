// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lending is ILending, State {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Update pool
        totalDeposits += usdc;
        
        // Calulate depositor tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        // Mint tUsdc to depositor
        tUSDC.defaultOperatorMint(msg.sender, _tUsdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }

    function withdraw(uint usdc) external {

        // Calulate withdrawer tUsdc
        uint _tUsdc = _usdcToTUsdc(usdc);

        // Burn withdrawer tUsdc
        tUSDC.operatorBurn(msg.sender, _tUsdc, "", "");

        // Update pool
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }
}