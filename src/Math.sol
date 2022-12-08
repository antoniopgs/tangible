// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";
import "./tUsdc.sol";

abstract contract Math {

    IERC20 public USDC;
    tUsdc public tUSDC;

    // System Vars
    PRBMath.UD60x18 internal totalDebt; // maybe rename to totalBorrowed?
    PRBMath.UD60x18 internal totalSupply;
    PRBMath.UD60x18 public maxLtv = uint(50).fromUint().div(uint(100).fromUint()); // 0.5

    // Interest Rate Vars
    PRBMath.UD60x18 public optimalUtilization;
    PRBMath.UD60x18 public m1;
    PRBMath.UD60x18 public b1;
    PRBMath.UD60x18 public m2;

    // Libs
    using PRBMathUD60x18Typed for PRBMath.UD60x18;
    using PRBMathUD60x18Typed for uint;

    function b2() private view returns (PRBMath.UD60x18 memory) {
        return optimalUtilization.mul(m1.sub(m2)).add(b1);
    }

    function utilization() public view returns (PRBMath.UD60x18 memory) {
        return totalDebt.div(totalSupply);
    }

    function currentYearlyRate() public view returns (PRBMath.UD60x18 memory) {

        // Get utilization
        PRBMath.UD60x18 memory _utilization = utilization();

        // If utilization <= optimalUtilization
        if (_utilization.value <= optimalUtilization.value) {
            return m1.mul(_utilization).add(b1);

        // If utilization > optimalUtilization
        } else {
            return m2.mul(_utilization).add(b2());
        }
    }

    function usdcToTusdcRatio() private view returns(PRBMath.UD60x18 memory) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalSupply.value == 0) {
            return uint(1).fromUint();

        } else {
            return tusdcSupply.fromUint().div(totalSupply);
        }
    }

    function usdcToTusdc(uint usdc) internal view returns(uint tusdc) {
        tusdc = usdc.fromUint().mul(usdcToTusdcRatio()).toUint();
    }

    function calculateMonthlyPayment(uint principal, PRBMath.UD60x18 memory monthlyRate, uint monthsCount) internal pure returns(PRBMath.UD60x18 memory monthlyPayment) {

        // Calculate r
        PRBMath.UD60x18 memory r = uint(1).fromUint().div(uint(1).fromUint().add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.fromUint().mul(uint(1).fromUint().sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }
}
