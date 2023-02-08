// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tUsdc.sol";
import "@prb/math/UD60x18.sol";
import "./ProsperaNft.sol";

abstract contract Base {

    // Tokens
    IERC20 public USDC;
    tUsdc public tUSDC;
    ProsperaNft prosperaNftContract;

    // Loan Terms
    UD60x18 internal monthlyBorrowerRate;
    uint internal loansMonthCount;
    UD60x18 public ltv;

    constructor(IERC20 _USDC, tUsdc _tUSDC, uint yearlyBorrowerRatePct, uint loansYearCount, uint ltvPct) {
        USDC = _USDC;
        tUSDC = _tUSDC;
        monthlyBorrowerRate = toUD60x18(yearlyBorrowerRatePct).div(toUD60x18(100)).div(toUD60x18(12));
        loansMonthCount = loansYearCount * 12;
        ltv = toUD60x18(ltvPct).div(toUD60x18(100));
    }
}
