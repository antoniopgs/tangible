// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../tokens/ProsperaNft.sol";
import "../../../tokens/tUsdc.sol";
import "@prb/math/UD60x18.sol";

abstract contract MortgageBase {

    // Tokens
    IERC20 public USDC;
    tUsdc public tUSDC;
    ProsperaNft prosperaNftContract;

    // Loan Terms
    UD60x18 internal monthlyBorrowerRate;
    uint internal loansMonthCount;
    UD60x18 public maxLtv;
    uint public allowedDelayedPayments;

    // System
    UD60x18 public utilizationCap;
    UD60x18 perfectLenderApy; // lenderApy if 100% utilization

    constructor(IERC20 _USDC, tUsdc _tUSDC, uint yearlyBorrowerRatePct, uint loansYearCount, uint maxLtvPct, uint utilizationCapPct, uint _allowedDelayedPayments) {
        USDC = _USDC;
        tUSDC = _tUSDC;
        monthlyBorrowerRate = toUD60x18(yearlyBorrowerRatePct).div(toUD60x18(100)).div(toUD60x18(12)); // yearlyBorrowerRate is the APR
        loansMonthCount = loansYearCount * 12;
        maxLtv = toUD60x18(maxLtvPct).div(toUD60x18(100));
        utilizationCap = toUD60x18(utilizationCapPct).div(toUD60x18(100));
        allowedDelayedPayments = _allowedDelayedPayments;

        // Calculate perfectLenderApy
        UD60x18 countCompoundingPeriods = toUD60x18(365 days).div(toUD60x18(30 days));
        perfectLenderApy = toUD60x18(1).add(monthlyBorrowerRate).pow(countCompoundingPeriods).sub(toUD60x18(1));
    }
}
