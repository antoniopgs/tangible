// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";

abstract contract LendingInfo is State {

    function _usdcToTUsdc(uint usdcAmount) internal view returns(uint tUsdcAmount) {
        
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