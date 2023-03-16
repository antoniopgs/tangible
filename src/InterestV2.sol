// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract InterestV2 {

    // Math Vars // Todo: figure out how to line-up concavity with optimalUtilization
    UD60x18 optimalUtilization;
    UD60x18 k1;
    UD60x18 k2;

    function utilization() public view returns(UD60x18) {} // Note: will later be inherited (only here for now so it compiles)
    function lenderApy() public view returns(UD60x18) {} // Note: will later be inherited (only here for now so it compiles)

    function borrowerRatePerSecond() private view returns(UD60x18) {
        return borrowerApr().div(toUD60x18(365 days));
    }

    function borrowerApr() public view returns (UD60x18) {
        return k1.add(k2.div(toUD60x18(1).sub(utilization())));
    }

    // Note: should be equal to tusdcSupply / totalDeposits
    function perfectTUsdcToUsdcRatio() private view returns (UD60x18) {
        return toUD60x18(1).add(lenderApy());
    }

    function tUsdcToUsdcRatio() public view returns (UD60x18) {
        
        // If utilization <= optimal
        if (utilization().lte(optimalUtilization)) {
            return perfectTUsdcToUsdcRatio();

        // If utilization > optimal (penalty slope)
        } else {
            return optimalUtilization.mul(weightedAvgBorrowerRate()).add(toUD60x18(1)).div(optimalUtilization.sub(toUD60x18(1)));
        }
    }

    function weightedAvgBorrowerRate() private view returns(UD60x18) {
        return lenderApy().div(utilization());
    }

    function perfectTUsdcToUsdc(uint tUsdc) private view returns(uint usdc) {
        usdc = fromUD60x18(toUD60x18(tUsdc).mul(perfectTUsdcToUsdcRatio()));
    }

    function tUsdcToUsdc(uint tUsdc) private view returns (uint usdc) {
        usdc = fromUD60x18(toUD60x18(tUsdc).mul(tUsdcToUsdcRatio()));
    }

    function withdrawPenalty(uint tUsdc) private view returns(uint) {
        return perfectTUsdcToUsdc(tUsdc) - tUsdcToUsdc(tUsdc);
    }
}