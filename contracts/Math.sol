// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Loan, Status } from "./types/Types.sol";

contract Math {

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    function balanceAt(Loan memory loan, uint second) private view returns(uint) {
        return (loan.paymentPerSecond * (1 - (1 + loan.ratePerSecond) ** (second - loan.maxDurationSeconds))) / loan.ratePerSecond;
    }

    function principalCapAt(Loan memory loan, uint loanMonth) private view returns(uint) {
        uint loanMonthStart = (loanMonth - 1) * monthSeconds;
        return balanceAt(loan, loanMonthStart);
    }

    function loanCurrentMonth(Loan memory loan) public view returns(uint) {
        uint activeTime = block.timestamp - loan.startTime;
        return (activeTime / monthSeconds) + 1;
    }

    function currentPrincipalCap(Loan memory loan) private view returns(uint) {
        return principalCapAt(loan, loanCurrentMonth(loan));
    }

    // Note: return defaultTime here too?
    function defaulted(Loan memory loan) private view returns(bool _defaulted) {
        return loan.unpaidPrincipal > currentPrincipalCap(loan);
    }

    function status(Loan memory loan) private view returns(Status) {

        if (loan.unpaidPrincipal == 0) {
            return Status.ResidentOwned;

        } else {

            if (defaulted(loan)) {
                return Status.Default;

            } else {
                return Status.Mortgage;
            }
        }
    }
}