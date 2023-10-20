// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../types/TimeConstants.sol";
import { Loan, Status } from "../../types/Types.sol";

abstract contract Amortization is TimeConstants {

    function balanceAt(Loan memory loan, uint second) private view returns(uint) {
        return (loan.paymentPerSecond * (1 - (1 + loan.ratePerSecond) ** (second - loan.maxDurationSeconds))) / loan.ratePerSecond;
    }

    function loanMonthStartSecond(uint loanMonth) private view returns(uint) {
        return (loanMonth - 1) * monthSeconds;
    }

    function principalCapAt(Loan memory loan, uint loanMonth) private view returns(uint) {
        return balanceAt(loan, loanMonthStartSecond(loanMonth));
    }

    function loanCurrentMonth(Loan memory loan) public view returns(uint) {
        uint activeTime = block.timestamp - loan.startTime;
        return (activeTime / monthSeconds) + 1; // Note: activeTime / monthSeconds always rounds down
    }

    function currentPrincipalCap(Loan memory loan) internal view returns(uint) {
        return principalCapAt(loan, loanCurrentMonth(loan));
    }
}