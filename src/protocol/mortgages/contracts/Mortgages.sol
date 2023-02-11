// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Supplying.sol";
import "./Lending.sol";
import "./Foreclosures.sol";

contract Mortgages is Supplying, Lending, Foreclosures {

    constructor (
        IERC20 _USDC,
        tUsdc _tUSDC,
        uint yearlyBorrowerRatePct,
        uint loansYearCount,
        uint maxLtvPct,
        uint utilizationCapPct,
        uint _allowedDelayedPayments
    ) MortgageBase(
        _USDC,
        _tUSDC,
        yearlyBorrowerRatePct,
        loansYearCount,
        maxLtvPct,
        utilizationCapPct,
        _allowedDelayedPayments
    ) {

    }
}
