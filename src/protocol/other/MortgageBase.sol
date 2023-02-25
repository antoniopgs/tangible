// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

abstract contract MortgageBase {

    // Loan Terms
    UD60x18 internal periodicBorrowerRate; // period is 30 days
    UD60x18 internal immutable compoundingPeriodsPerYear = toUD60x18(365).div(toUD60x18(30)); // period is 30 days
    UD60x18 internal installmentCount;
    UD60x18 public maxLtv;

    // System
    UD60x18 public utilizationCap;
    UD60x18 perfectLenderApy; // lenderApy if 100% utilization

    constructor(uint yearlyBorrowerRatePct, uint loansYearCount, uint maxLtvPct, uint utilizationCapPct) {
        periodicBorrowerRate = toUD60x18(yearlyBorrowerRatePct).mul(toUD60x18(30)).div(toUD60x18(100)).div(toUD60x18(365)); // yearlyBorrowerRate is the APR
        installmentCount = toUD60x18(loansYearCount * 365).div(toUD60x18(30)); // make it separate from compoundingPeriodsPerYear to move div later (and increase precision)
        maxLtv = toUD60x18(maxLtvPct).div(toUD60x18(100));
        utilizationCap = toUD60x18(utilizationCapPct).div(toUD60x18(100));
        perfectLenderApy = toUD60x18(1).add(periodicBorrowerRate).pow(compoundingPeriodsPerYear).sub(toUD60x18(1));
    }
}
