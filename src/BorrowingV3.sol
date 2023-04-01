// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, toUD60x18, fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";

import "forge-std/console.sol";

contract BorrowingV3 {

    // Time constants
    uint private constant yearSeconds = 365 days;
    uint private constant yearMonths = 12;
    uint private constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)
    
    // Structs
    struct Loan {
        address borrower;
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint startTime;
        uint unpaidPrincipal;
        uint maxUnpaidInterest;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    // Pool vars
    uint totalPrincipal;
    uint totalDeposits;
    uint maxTotalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Other vars
    UD60x18 one = toUD60x18(1);

    // Functions
    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) external {

        // console.log(1);

        // Calculate ratePerSecond
        UD60x18 ratePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));

        // console.log(2);

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationYears * yearSeconds;

        // console.log(3);

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);

        // console.log(4);

        // Calculate maxCost
        uint maxCost = fromUD60x18(paymentPerSecond) * maxDurationSeconds;

        // console.log(5);
        // console.log("maxCost:", maxCost);
        // console.log("principal:", principal);

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;

        // console.log(6);
        
        loans[tokenId] = Loan({
            borrower: msg.sender,
            ratePerSecond: ratePerSecond,
            paymentPerSecond: paymentPerSecond,
            startTime: block.timestamp,
            unpaidPrincipal: principal,
            maxUnpaidInterest: maxUnpaidInterest,
            maxDurationSeconds: maxDurationSeconds,
            lastPaymentTime: block.timestamp // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now
        });

        // console.log(7);

        // Update pool
        totalPrincipal += principal;
        maxTotalInterestOwed += maxUnpaidInterest;
    }

    function payLoan(uint tokenId, uint payment) external {

        console.log(0);

        // Get Loan
        Loan storage loan = loans[tokenId];

        console.log(1);

        // Calculate interest
        uint interest = accruedInterest(loan);
        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment => interest, "payment must be => interest"); // Question: maybe don't calculate repayment if payment < interest?

        console.log(2);
        console.log("payment:", payment);
        console.log("interest:", interest);

        // Calculate repayment
        uint repayment = payment - interest; // Question: enforce payment > interest? or allow to pay only interest with if/else?

        console.log(3);
        console.log("loan.unpaidPrincipal:", loan.unpaidPrincipal);
        console.log("repayment:", repayment);

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.lastPaymentTime = block.timestamp;

        console.log(4);
        console.log("totalPrincipal:", totalPrincipal);
        console.log("repayment:", repayment);
        console.log("totalDeposits:", totalDeposits);
        console.log("interest:", interest);
        console.log("maxTotalInterestOwed:", maxTotalInterestOwed);
        console.log("interest:", interest);

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        maxTotalInterestOwed -= interest;

        console.log(5);

        // If loan is paid off
        if (loan.unpaidPrincipal == 0) {

            // Clear out loan
            loan.borrower = address(0);  
        }
    }

    function redeem(uint tokenId) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Default

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest;

        // Redeem (pull defaulter's entire debt)

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Question: or should it be "maxTotalInterestOwed -= (loan.maxUnpaidInterest - interest)?

        // Clearout loan
    }

    function foreclose(uint tokenId, uint salePrice) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure State == Foreclosurable

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest; // Todo: add fees later

        // Ensure salePrice covers defaulterDebt + fees
        require(salePrice >= defaulterDebt, "salePrice must >= defaulterDebt"); // Note: minSalePrice will rise over time. Too risky?

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Question: or should it be "maxTotalInterestOwed -= (loan.maxUnpaidInterest - interest)?

        // Clearout loan

        // Send defaulterEquity to defaulter
    }
    
    // Public Views
    function defaulted(uint tokenId) public view returns(bool) {
        Loan memory loan = loans[tokenId];
        return loan.unpaidPrincipal > currentPrincipalCap(tokenId);
    }

    function utilization() public view returns(UD60x18) {
        return toUD60x18(totalPrincipal).div(toUD60x18(totalDeposits));
    }

    function lenderApy() public view returns(UD60x18) {
        return toUD60x18(maxTotalInterestOwed).div(toUD60x18(totalDeposits)); // Question: is this missing auto-compounding?
    }

    function currentPrincipalCap(uint tokenId) public view returns(uint) {
        return principalCap(tokenId, loanCompletedMonths(tokenId));
    }

    // Other Views
    function principalCap(uint tokenId, uint month) private view returns(uint cap) {

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

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) private view returns(UD60x18 paymentPerSecond) {

        // Calculate x
        UD60x18 x = one.add(ratePerSecond).powu(maxDurationSeconds);
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(one));
    }

    function accruedInterest(Loan memory loan) private view returns(uint) {
        return fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }
    
    // For testing
    function accruedInterest(uint tokenId) public view returns(uint) {
        return accruedInterest(loans[tokenId]);
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(toUD60x18(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}