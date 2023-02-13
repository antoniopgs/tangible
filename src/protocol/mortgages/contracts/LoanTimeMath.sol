// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./MortgageBase.sol";

abstract contract LoanTimeMath is MortgageBase {

    // Math Vars
    UD60x18 internal totalBorrowed;
    UD60x18 internal totalDeposits;

    function utilization() public view returns (UD60x18) {
        return totalBorrowed.div(totalDeposits);
    }

    function lenderApy() public view returns (UD60x18) {
        return perfectLenderApy.mul(utilization());
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

    function calculateInstallment(UD60x18 principal) internal view returns(UD60x18 monthlyPayment) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicBorrowerRate).pow(installmentCount);
        
        // Calculate monthlyPayment
        monthlyPayment = principal.mul(periodicBorrowerRate).mul(x).div(x.sub(toUD60x18(1)));
    }
}
