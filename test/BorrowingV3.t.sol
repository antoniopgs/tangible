// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/BorrowingV3.sol";
import "forge-std/console.sol";

contract BorrowingV3Test is Test {

    enum Action { Start, Pay, Skip }

    BorrowingV3 borrowing = new BorrowingV3();
    uint loanCount;
    uint paidInterest;

    function testMath(uint[] calldata randomness) public {

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Start)) {
                
                // Set tokenId
                uint tokenId = loanCount;

                // Start Loan
                startLoan(tokenId, randomness[i]);

                // Increment loanCount
                loanCount++;
            
            // If Pay
            } else if (action == uint(Action.Pay)) {
                
                // If loans exist
                if (loanCount > 0) {

                    // Get random tokenId
                    uint tokenId = randomness[i] % loanCount;

                    // Pay Loan
                    payLoan(tokenId, randomness[i]);

                }
            
            // If Skip
            } else if (action == uint(Action.Skip)) {

                // Skip
                skipTime(randomness[i]);
            }
        }
    }

    function startLoan(uint tokenId, uint randomness) private {
        
        // Bound vars
        uint principal = bound(randomness, 1e18, 1_000_000e18);
        uint borrowerAprPct = bound(randomness, 2, 10);
        uint maxDurationYears = bound(randomness, 1, 50);

        // Calculate expectations
        uint expectedTotalPrincipal = borrowing.totalPrincipal() + principal;
        uint expectedTotalDeposits = borrowing.totalDeposits();
        // uint expectedMaxTotalInterestOwed = borrowing.totalPrincipal() + principal;
        
        // Start Loan
        console.log("starting loan...");
        console.log("- principal:", principal);
        console.log("- borrowerAprPct:", borrowerAprPct);
        console.log("- maxDurationYears:", maxDurationYears);
        borrowing.startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);
        console.log("loan started.\n");

        // Validate expectations
        assert(expectedTotalPrincipal == borrowing.totalPrincipal());
        assert(expectedTotalDeposits == borrowing.totalDeposits());
        // assert(expectedMaxTotalInterestOwed == borrowing.maxTotalInterestOwed())
    }

    function skipTime(uint timeJump) private {

        // Bound timeJump (between 0 and 6 months)
        timeJump = bound(timeJump, 0, 6 * 30 days);

        // Skip by timeJump
        console.log("skipping time by", timeJump);
        skip(timeJump);
        console.log("time skipped.\n");
    }

    function payLoan(uint tokenId, uint payment) private {
        
        // Get unpaidPrincipal & interest
        (, , , , uint unpaidPrincipal, , , ) = borrowing.loans(tokenId);
        uint interest = borrowing.accruedInterest(tokenId);

        // Calculate minPayment & maxPayment
        uint minPayment = interest;
        uint maxPayment = unpaidPrincipal + interest;

        // Bound payment
        payment = bound(payment, minPayment, maxPayment);

        // Calculate expectations
        uint expectedInterest = borrowing.accruedInterest(tokenId);
        uint expectedRepayment = payment - expectedInterest;
        uint expectedTotalPrincipal = borrowing.totalPrincipal() - expectedRepayment;
        uint expectedTotalDeposits = borrowing.totalDeposits() + expectedInterest;
        uint expectedMaxTotalInterestOwed = borrowing.maxTotalInterestOwed() - interest;

        // Pay Loan
        console.log("making payment...");
        console.log("- payment:", payment);
        paidInterest += expectedInterest;
        borrowing.payLoan(tokenId, payment);
        console.log("payment made.\n");

        // Validate expectations
        console.log(1);
        assert(expectedTotalPrincipal == borrowing.totalPrincipal());
        console.log(2);
        assert(expectedTotalDeposits == borrowing.totalDeposits());
        console.log(3);
        assert(expectedMaxTotalInterestOwed == borrowing.maxTotalInterestOwed());
        console.log(4);
        assert(paidInterest <= borrowing.maxTotalInterestOwed());
        console.log(5);

        // If loan is paid off, return
        (address borrower, , , , , , , ) = borrowing.loans(tokenId);
        if (borrower == address(0)) {
            console.log("loan paid off.\n");
            return;
        }
    }
}