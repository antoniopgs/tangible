// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/ILending.sol";
import "../state/state/State.sol";

contract Lending is ILending, State {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {
        
        // Pull usdc from depositor
        USDC.safeTransferFrom(msg.sender, address(this), usdc); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Calulate depositor tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Update pool
        _totalDeposits += usdc; // Note: must come after _usdcToTUsdc()

        // Mint tUsdc to depositor
        tUSDC.mint(msg.sender, _tUsdc);

        emit Deposit(msg.sender, usdc, _tUsdc);
    }

    function withdraw(uint usdc) external {
        require(usdc <= _availableLiquidity(), "not enough available liquidity");

        // Calulate withdrawer tUsdc
        uint _tUsdc = usdcToTUsdc(usdc);

        // Burn withdrawer tUsdc
        tUSDC.burn(msg.sender, _tUsdc);

        // Update pool
        _totalDeposits -= usdc; // Note: must come after _usdcToTUsdc()

        // Send usdc to withdrawer
        USDC.safeTransfer(msg.sender, usdc);

        emit Withdraw(msg.sender, usdc, _tUsdc);
    }

    function usdcToTUsdc(uint usdcAmount) public view returns(uint tUsdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || _totalDeposits == 0) {
            tUsdcAmount = usdcAmount * 1e12; // Note: tUSDC has 12 more decimals than USDC

        } else {
            tUsdcAmount = usdcAmount * tUsdcSupply / _totalDeposits; // Note: multiplying by tUsdcSupply removes need to add 12 decimals
        }
    }
}