// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInfo.sol";
import "../debts/debtsMath/DebtsMath.sol";
import "../state/State.sol";

contract Info is IInfo, DebtsMath, State {

    // Residents
    function isResident(address addr) external view returns (bool) {
        return _isResident(addr);
    }

    // Pool
    function availableLiquidity() external view returns(uint) {
        return _availableLiquidity();
    }

    function utilization() external view returns(UD60x18) {
        return _utilization();
    }

    function usdcToTUsdc(uint usdcAmount) external view returns(uint tUsdcAmount) {
        return _usdcToTUsdc(usdcAmount);
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

    // Auctions
    function bidActionable(uint tokenId, uint idx) external view returns(bool) {
        return _bidActionable(bids[tokenId][idx]);
    }

    // Token Debts
    function unpaidPrincipal(uint tokenId) external view returns(uint) {
        return debts[tokenId].loan.unpaidPrincipal;
    }

    function accruedInterest(uint tokenId) external view returns(uint) {
        return _accruedInterest(debts[tokenId].loan);
    }
}