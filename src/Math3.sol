// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract Math3 {

    function calculateMonthlyPayment(uint principal, uint monthlyRate, uint monthsCount) private pure returns(uint monthlyPayment) {
        uint r = 1 / (1 + monthlyRate);
        monthlyPayment = principal * ((1 - r) / (r - r ** (monthsCount + 1)));
    }
}