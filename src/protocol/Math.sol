// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Base.sol";

abstract contract Math is Base {

    // System Vars
    UD60x18 internal totalBorrowed; // maybe rename to totalBorrowed?
    // UD60x18 internal interestOwed;
    UD60x18 internal totalDeposits;

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }

    function lenderApy() public view returns (UD60x18) {
        return monthlyBorrowerRate.mul(toUD60x18(12)).mul(utilization());
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

    function usdcToTusdc(uint usdc) internal view returns(uint tusdc) {
        tusdc = fromUD60x18(toUD60x18(usdc).mul(usdcToTusdcRatio()));
    }

    function calculateMonthlyPayment(UD60x18 principal) internal view returns(UD60x18 monthlyPayment) {

        // Calculate r
        UD60x18 r = toUD60x18(1).div(toUD60x18(1).add(monthlyBorrowerRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.mul(toUD60x18(1).sub(r).div(r.sub(r.powu(loansMonthCount + 1))));
    }
}
