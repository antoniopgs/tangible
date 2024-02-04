// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Inheritance
import { PoolBase } from "./PoolBase.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Other
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PoolLending is PoolBase, ERC20 {

    event Deposit(address depositor, uint amount, uint tUsdcMint);
    event Withdraw(address withdrawer, uint amount, uint tUsdcBurn);

    uint debt;
    uint deposits;

    using SafeERC20 for IERC20;

    function _deposit(uint underlying) internal {

        // Calulate caller shares
        uint shares = underlyingToShares(underlying);

        // Update deposits
        deposits += underlying;
        
        // Pull underlying from caller
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlying); // Note: must come after underlyingToShares()

        // Mint shares to caller
        _mint(msg.sender, shares);

        // Log
        emit Deposit(msg.sender, underlying, shares);
    }

    function _withdraw(uint underlying) internal {
        require(underlying <= availableLiquidity(), "not enough available liquidity");

        // Calulate caller shares
        uint shares = underlyingToShares(underlying);

        // Update deposits
        deposits -= underlying;

        // Burn caller shares
        _burn(msg.sender, shares);

        // Send underlying to caller
        UNDERLYING.safeTransfer(msg.sender, underlying); // Note: must come after underlyingToShares
        
        // Log
        emit Withdraw(msg.sender, underlying, shares);
    }

    // Todo: implement ERC4626 vault to mitigate inflation attack?
    function underlyingToShares(uint underlying) public view returns(uint shares) {
        
        // Get supply
        uint supply = totalSupply();

        // Get underlyingBalance
        uint underlyingBalance = UNDERLYING.balanceOf(address(this));

        // If supply or underlyingBalance = 0, 1:1
        if (supply == 0 || underlyingBalance == 0) {
            shares = underlying * 1e12; // Note: Pool has 12 more decimals than UNDERLYING

        } else {
            shares = underlying * supply / underlyingBalance; // Note: multiplying by supply removes need to add 12 decimals
        }
    }

    function availableLiquidity() public view returns(uint) {
        return deposits - debt;
    }
}