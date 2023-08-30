// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/State.sol";

abstract contract PoolInfo is State {

    function _usdcToTUsdc(uint usdcAmount) internal view returns(uint tUsdcAmount) {
        
        // Get tUsdcSupply
        uint tUsdcSupply = tUSDC.totalSupply();

        // If tUsdcSupply or totalDeposits = 0, 1:1
        if (tUsdcSupply == 0 || totalDeposits == 0) {
            return tUsdcAmount = usdcAmount;
        }

        // Calculate tUsdcAmount
        return tUsdcAmount = usdcAmount * tUsdcSupply / totalDeposits;
    }

}