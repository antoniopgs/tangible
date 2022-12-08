// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Base.sol";
import "@prb/math/UD60x18.sol";

abstract contract Math is Base {

    // System Vars
    UD60x18 internal totalDebt; // maybe rename to totalBorrowed?
    UD60x18 internal totalSupply;

    function utilization() public view returns (UD60x18 ) {
        return totalDebt.div(totalSupply);
    }

    function usdcToTusdcRatio() private view returns(UD60x18 ) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalSupply.eq(ud(0))) {
            return toUD60x18(1);

        } else {
            return toUD60x18(tusdcSupply).div(totalSupply);
        }
    }

    function usdcToTusdc(uint usdc) internal view returns(uint tusdc) {
        tusdc = fromUD60x18(toUD60x18(usdc).mul(usdcToTusdcRatio()));
    }

    function calculateMonthlyPayment(uint principal, UD60x18 monthlyRate, uint monthsCount) internal pure returns(UD60x18 monthlyPayment) {

        // Calculate r
        UD60x18 r = toUD60x18(1).div(toUD60x18(1).add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = toUD60x18(principal).mul(toUD60x18(1).sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }
}
