// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILending.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lending is ILending, State {

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint assets) external {
        
        // Pull assets from depositor
        ASSETS.safeTransferFrom(msg.sender, address(this), assets);

        // Calulate depositor shares
        uint shares = assetsToShares(assets);

        // Update pool
        // Note: must come after assetsToShares()
        // Note: use _totalDeposits var instead of balanceOf(address(this)) to avoid donation attack
        _totalDeposits += assets;

        // Mint shares to depositor
        SHARES.mint(msg.sender, shares);

        // Emit Deposit event
        emit Deposit(msg.sender, assets, shares);
    }

    function withdraw(uint assets) external {
        require(assets <= availableLiquidity(), "not enough available liquidity");

        // Calulate withdrawer shares
        uint shares = assetsToShares(assets);

        // Burn withdrawer shares
        SHARES.burn(msg.sender, shares);

        // Update pool
        // Note: must come after assetsToShares()
        // Note: use _totalDeposits var instead of balanceOf(address(this)) to avoid donation attack
        _totalDeposits -= assets;

        // Send assets to withdrawer
        ASSETS.safeTransfer(msg.sender, assets);

        // Emit Withdrawal event
        emit Withdraw(msg.sender, assets, shares);
    }

    function assetsToShares(uint assets) private view returns(uint shares) {
        
        // Get totalShares
        uint totalShares = SHARES.totalSupply();

        // If totalShares or totalDeposits = 0, 1:1
        if (totalShares == 0 || _totalDeposits == 0) {
            shares = assets * 1e12; // Note: shares has 12 more decimals than assets

        } else {
            shares = assets * totalShares / _totalDeposits; // Note: multiplying by totalShares removes need to add 12 decimals
        }
    }

    function availableLiquidity() private view returns(uint) {
        return _totalDeposits - _totalPrincipal; // Question: - protocolMoney?
    }
}