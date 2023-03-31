// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, toUD60x18, fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";

contract BorrowingV3 {

    // Time constants
    uint private constant yearSeconds = 365 days;
    uint private constant yearMonths = 12;
    uint private constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)
    
    // Structs
    struct Loan {
        UD60x18 ratePerSecond;
        uint maxDurationSeconds;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        uint lastPaymentTime;
    }

    // Pool vars
    uint totalPrincipal;
    uint totalDeposits;
    uint totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Other vars
    UD60x18 one = toUD60x18(1);

    // Functions
    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) external {

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

        // Update pool
        totalPrincipal += principal;
        totalInterestOwed += ;
    }

    function payLoan(uint tokenId, uint payment) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(lastPaymentElapsedSeconds(loan)));

        // Calculate interest
        uint interest = fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate));

        // Calculate repayment
        uint repayment = payment - interest;

        // Update loan
        loan.unpaidPrincipal -= repayment;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        totalInterestOwed -= interest;
    }

    function redeem(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Default

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(lastPaymentElapsedSeconds(loan)));

        // Calculate interest
        uint interest = fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate));

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest;

        // Redeem (pull defaulter's entire debt)

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        totalInterestOwed -= interest; // Note: this might be off (because in startLoan() I added maxUnpaidInterest to totalInterestOwed)

        // Clearout loan
    }

    function foreclose(uint tokenId, uint salePrice) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Foreclosurable

        // Calculate accruedRate
        UD60x18 accruedRate = loan.ratePerSecond.mul(toUD60x18(lastPaymentElapsedSeconds(loan)));

        // Calculate interest
        uint interest = fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate));

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest; // Todo: add fees later

        // Ensure salePrice covers defaulterDebt + fees

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        totalInterestOwed -= interest; // Note: this might be off (because in startLoan() I added maxUnpaidInterest to totalInterestOwed)

        // Clearout loan

        // Send defaulterEquity to defaulter
    }
    
    // Views
    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) private view returns(UD60x18 paymentPerSecond) {

        // Calculate x
        UD60x18 x = one.add(ratePerSecond).powu(maxDurationSeconds);
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(one));
    }

    function principalCap(uint tokenId, uint month) public view returns(uint cap) {

        // Get loan
        Loan memory loan = loans[tokenId];

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = toSD59x18(int(elapsedSeconds)).sub(toSD59x18(int(loan.maxDurationSeconds))).sub(toSD59x18(1));

        // Calculate z
        UD60x18 z = UD60x18.wrap(uint(SD59x18.unwrap(SD59x18.wrap(int(UD60x18.unwrap(one.add(loan.ratePerSecond)))).pow(negExponent))));

        // Calculate cap
        cap = fromUD60x18(loan.paymentPerSecond.mul(one.sub(z)).div(loan.ratePerSecond));
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
        return loan.unpaidPrincipal > currentPrincipalCap(tokenId);
    }

    function lastPaymentElapsedSeconds(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}