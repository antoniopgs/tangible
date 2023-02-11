// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Lending.sol";
import "./Borrowing.sol";

contract Mortgages is Lending, Borrowing { // IMPROVE MODULARITY LATER

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
