// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "./YieldToken.sol";

contract Lending {

    // Events
    event Deposit(address depositor, uint underlying, uint yieldMint);
    event Withdrawal(address withdrawer, uint underlying, uint yieldBurn);

    // Tokens
    IERC20 underlyingToken;
    YieldToken yieldToken;

    // Vars
    uint _totalPrincipal;
    uint _totalDeposits;

    // Libs
    using SafeERC20 for IERC20;

    function deposit(uint underlying) external {
        
        // Pull underlying from depositor
        underlyingToken.safeTransferFrom(msg.sender, address(this), underlying);

        // Calulate depositor's yieldMint
        uint yieldMint = underlyingToYield(underlying);

        // Update pool
        _totalDeposits += underlying; // Note: must come after underlyingToYield()

        // Mint tUsdc to depositor
        yieldToken.mint(msg.sender, yieldMint);

        emit Deposit(msg.sender, underlying, yieldMint);
    }

    function withdraw(uint underlying) external {

        // Calulate withdrawer's yieldBurn
        uint yieldBurn = underlyingToYield(underlying);

        // Burn withdrawer's yieldBurn
        yieldToken.burn(msg.sender, yieldBurn);

        // Update pool
        _totalDeposits -= underlying; // Note: must come after _usdcToTUsdc()
        require(_totalPrincipal <= _totalDeposits, "utilization can't exceed 100%");

        // Send underlying to withdrawer
        underlyingToken.safeTransfer(msg.sender, underlying);

        emit Withdrawal(msg.sender, underlying, yieldBurn);
    }

    function underlyingToYield(uint underlying) internal view returns(uint yield) {
        
        // Get yieldSupply
        uint yieldSupply = yieldToken.totalSupply();

        // If yieldSupply or totalDeposits = 0, 1:1
        if (yieldSupply == 0 || _totalDeposits == 0) {
            yield = underlying /* * 1e12 */; // Note: yield has 12 more decimals than underlying

        } else {
            yield = underlying * yieldSupply / _totalDeposits; // Note: multiplying by yieldSupply removes need to add decimals
        }
    }
}