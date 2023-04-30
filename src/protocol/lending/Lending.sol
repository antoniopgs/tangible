// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lending is ILending, Status {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Update pool
        totalDeposits += usdc;
        
        // Calulate depositor tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Mint tUsdc to depositor
        tUSDC.defaultOperatorMint(msg.sender, _tUsdc);
    }

    function withdraw(uint usdc) external {

        // Calulate withdrawer tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Burn withdrawer tUsdc
        tUSDC.operatorBurn(msg.sender, _tUsdc, "", "");

        // Update pool
        totalDeposits -= usdc;
        require(totalPrincipal <= totalDeposits, "utilization can't exceed 100%");

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);
    }

    function usdcToTUsdc(uint usdcAmount) public view returns(uint tUsdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return tUsdcAmount = usdcAmount;
        }

        // Calculate tUsdcAmount
        return tUsdcAmount = usdcAmount * tUsdcSupply / totalDeposits;
    }

    function tUsdcToUsdc(uint tUsdcAmount) public view returns(uint usdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return usdcAmount = tUsdcAmount;
        }

        // Calculate usdcAmount
        return usdcAmount = tUsdcAmount * totalDeposits / tUsdcSupply;
    }
}