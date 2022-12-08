// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";
import "./tUsdc.sol";

abstract contract Math {

    IERC20 public USDC;
    tUsdc public tUSDC;

    // System Vars
    UD60x18 internal totalDebt; // maybe rename to totalBorrowed?
    UD60x18 internal totalSupply;
    UD60x18 public maxLtv = uint(50).fromUint().div(uint(100).fromUint()); // 0.5

    // Interest Rate Vars
    UD60x18 public optimalUtilization;
    UD60x18 public m1;
    UD60x18 public b1;
    UD60x18 public m2;

    function b2() private view returns (UD60x18 ) {
        return optimalUtilization.mul(m1.sub(m2)).add(b1);
    }

    function utilization() public view returns (UD60x18 ) {
        return totalDebt.div(totalSupply);
    }

    function currentYearlyRate() public view returns (UD60x18 ) {

        // Get utilization
        UD60x18  _utilization = utilization();

        // If utilization <= optimalUtilization
        if (_utilization.value <= optimalUtilization.value) {
            return m1.mul(_utilization).add(b1);

        // If utilization > optimalUtilization
        } else {
            return m2.mul(_utilization).add(b2());
        }
    }

    function usdcToTusdcRatio() private view returns(UD60x18 ) {
        
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

    function calculateMonthlyPayment(uint principal, UD60x18  monthlyRate, uint monthsCount) internal pure returns(UD60x18  monthlyPayment) {

        // Calculate r
        UD60x18  r = uint(1).fromUint().div(uint(1).fromUint().add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.fromUint().mul(uint(1).fromUint().sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }
}
