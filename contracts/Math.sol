// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { Loan } from "./types/Types.sol";

contract Math {

    function balanceAt(Loan memory loan, uint second) private view returns(uint) {
        return loan.paymentPerSecond * (1 - (1 + loan.ratePerSecond) ** (second - loan.maxDurationSeconds)) / loan.ratePerSecond;
    }

    function principalCapAt(Loan memory loan, uint loanMonth) public view returns(uint) {
        lastMonth = loan.maxDurationSeconds / monthSeconds;
        require(loanMonth >= 1 && loanMonth <= lastMonth, "invalid loanMonth");
        uint loanMonthStart = (loanMonth - 1) * monthSeconds;
        return balanceAt(loan, loanMonthStart);
    }

    function loanMonth(Loan memory loan, uint currentMonth) public view returns(uint) {

    }
}