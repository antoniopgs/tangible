// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/SD59x18.sol";

contract BorrowingV3 {

    // Time vars
    SD59x18 private yearSeconds = toSD59x18(365 days);
    SD59x18 private yearMonths = toSD59x18(12);
    SD59x18 private monthSeconds = yearSeconds.div(yearMonths);

    // Other vars
    SD59x18 one = toSD59x18(1);

    struct Loan {
        SD59x18 ratePerSecond;
        SD59x18 maxDurationSeconds; // Note: maybe switch to uint
        SD59x18 paymentPerSecond;
    }

    mapping(uint => Loan) public loans;

    function startLoan(uint tokenId, int principal, int borrowerAprPct, int maxDurationYears) public {

        SD59x18 ratePerSecond = toSD59x18(borrowerAprPct).div(toSD59x18(100)).div(yearSeconds);

        SD59x18 maxDurationSeconds = toSD59x18(maxDurationYears).mul(yearSeconds);
        
        loans[tokenId] = Loan({
            ratePerSecond: ratePerSecond,
            maxDurationSeconds: maxDurationSeconds,
            paymentPerSecond: calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds)
        });
    }
    
    function calculatePaymentPerSecond(int principal, SD59x18 ratePerSecond, SD59x18 maxDurationSeconds) private view returns(SD59x18 paymentPerSecond) {

        // Calculate x
        SD59x18 x = toSD59x18(1).add(ratePerSecond).pow(maxDurationSeconds);
        
        // Calculate paymentPerSecond
        paymentPerSecond = toSD59x18(principal).mul(ratePerSecond).mul(x).div(x.sub(one));
    }

    function principalCap(uint tokenId, int month) public view returns(int) {
        Loan memory loan = loans[tokenId];
        SD59x18 elapsedSeconds = toSD59x18(month).mul(monthSeconds);
        SD59x18 _principalCap = loan.paymentPerSecond.mul(one.sub(one.add(loan.ratePerSecond).pow(elapsedSeconds.sub(loan.maxDurationSeconds.sub(one))))).div(loan.ratePerSecond);
        return fromSD59x18(_principalCap);
    }
}

