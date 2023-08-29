// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IPool.sol";
import "../state/State.sol";

contract Pool is IPool, State {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Update pool
        totalDeposits += usdc;
        
        // Calulate depositor tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Mint tUsdc to depositor
        tUSDC.defaultOperatorMint(msg.sender, _tUsdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
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

        emit Deposit(msg.sender, usdc, _tUsdc);
    }

    function availableLiquidity() external view returns(uint) {
        return totalDeposits - totalPrincipal; // - protocolMoney?
    }

    function _availableLiquidity() internal view returns(uint) {
        return totalDeposits - totalPrincipal; // - protocolMoney?
    }

    function utilization() external view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return convert(uint(0));
        }
        return convert(totalPrincipal).div(convert(totalDeposits));
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

    function tUsdcToUsdc(uint tUsdcAmount) external view returns(uint usdcAmount) {
        
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