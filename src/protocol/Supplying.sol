// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/ISupplying.sol";
import "./Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Supplying is ISupplying, Math {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {

        // Pull LIQ from staker
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Add usdc to totalSupply
        totalSupply = totalSupply.add(toUD60x18(usdc));

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Mint tusdc to depositor
        tUSDC.mint(msg.sender, tusdc);
    }

    function withdraw(uint usdc) external {

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Burn tusdc from withdrawer/msg.sender
        tUSDC.burn(tusdc, "");

        // Send LIQ to unstaker
        USDC.safeTransfer(msg.sender, usdc); // reentrancy possible?

        // Remove usdc from totalSupply
        totalSupply = totalSupply.sub(toUD60x18(usdc));
        require(totalSupply.gte(totalDebt), "utilzation can't exceed 100%");
    }    
}
