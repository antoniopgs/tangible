// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, toUD60x18, fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";

contract BorrowingV3 {

    // Time vars
    uint private constant yearSeconds = 365 days;
    uint private constant yearMonths = 12;
    uint private constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    // Other vars
    UD60x18 one = toUD60x18(1);

    struct Loan {
        UD60x18 ratePerSecond;
        uint maxDurationSeconds;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint balance;
        uint lastPaymentTime;
    }

    mapping(uint => Loan) public loans;

    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) public {

        UD60x18 ratePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));

        uint maxDurationSeconds = maxDurationYears * yearSeconds;
        
        loans[tokenId] = Loan({
            ratePerSecond: ratePerSecond,
            maxDurationSeconds: maxDurationSeconds,
            paymentPerSecond: calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds),
            startTime: block.timestamp,
            balance: principal,
            lastPaymentTime: block.timestamp // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now
        });
    }
    
    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) private view returns(UD60x18 paymentPerSecond) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(maxDurationSeconds);
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(one));
    }

    function principalCap(uint tokenId, uint month) public view returns(uint) {
        Loan memory loan = loans[tokenId];
        uint elapsedSeconds = month * monthSeconds;
        SD59x18 negExponent = toSD59x18(int(elapsedSeconds)).sub(toSD59x18(int(loan.maxDurationSeconds))).sub(toSD59x18(1));
        SD59x18 numerator = loan.paymentPerSecond.mul(one.sub(one.add(loan.ratePerSecond).pow(negExponent)));
        return fromUD60x18(numerator.div(loan.ratePerSecond));
    }

    // Note: truncates on purpose (to enforce payment after monthSeconds, but not every second)
    function loanCompletedMonths(uint tokenId) private view returns(uint) {
        Loan memory loan = loans[tokenId];
        return (block.timestamp - loan.startTime) / monthSeconds;
    }

    function currentPrincipalCap(uint tokenId) public view returns(uint) {
        return principalCap(tokenId, loanCompletedMonths(tokenId));
    }

    function defaulted(uint tokenId) public view returns(bool) {
        Loan memory loan = loans[tokenId];
        return loan.balance > currentPrincipalCap(tokenId);
    }

    function lastPaymentElapsedSeconds(Loan memory loan) private returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }


    function payLoan(uint tokenId, uint payment) private {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Calculate interest
        uint interest = loan.ratePerSecond * lastPaymentElapsedSeconds(loan);

        // Calculate repayment
        uint repayment = payment - interest;

        // Update loan
        loan.balance -= repayment;
    }
}