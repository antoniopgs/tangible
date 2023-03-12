// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lending is ILending, State {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint usdc) external {

        // Pull LIQ from staker
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Add usdc to totalDeposits
        totalDeposits = totalDeposits.add(toUD60x18(usdc));

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Mint tusdc to depositor
        tUSDC.mint(msg.sender, tusdc);

        // Emit event
        emit Deposit(msg.sender, usdc, tusdc, block.timestamp);
    }

    function withdraw(uint usdc) external {

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Burn tusdc from withdrawer/msg.sender
        tUSDC.burn(tusdc, "");

        // Send LIQ to unstaker
        USDC.safeTransfer(msg.sender, usdc); // reentrancy possible?

        // Remove usdc from totalDeposits
        totalDeposits = totalDeposits.sub(toUD60x18(usdc));
        require(utilization().lte(utilizationCap), "utilization can't exceed utilizationCap");

        // Emit event
        emit Withdrawal(msg.sender, usdc, tusdc, block.timestamp);
    }

    function usdcToTusdcRatio() private view returns(UD60x18) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalDeposits.eq(ud(0))) {
            return toUD60x18(1);

        } else {
            return toUD60x18(tusdcSupply).div(totalDeposits);
        }
    }

    function usdcToTusdc(uint usdc) private view returns(uint tusdc) {
        tusdc = fromUD60x18(toUD60x18(usdc).mul(usdcToTusdcRatio()));
    }   
}
