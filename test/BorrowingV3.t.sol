// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/BorrowingV3.sol";
import "forge-std/console.sol";

contract BorrowingV3Test is Test {

    BorrowingV3 borrowing = new BorrowingV3();

    function testMath(uint[] calldata randomness, uint principal, uint borrowerAprPct, uint maxDurationYears) public {

        uint tokenId = 0;
        
        // Start Loan
        startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);

        for (uint i = 0; i < randomness.length; i++) {
            
            // Set random timeJump (between 0 and 6 months)
            uint timeJump = bound(randomness[i], 0, 6 * 30 days);

            // Skip by timeJump
            console.log("skipping time by", timeJump);
            skip(timeJump);
            console.log("time skipped.\n");

            // If no default
            if (!borrowing.defaulted(tokenId)) {

                // Pay Loan (with random payment)
                payLoan(tokenId, randomness[i]);

            } else {
                console.log("defaulted.\n");
                return;
            }
        }

    }

    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) private {
        
        // Bound vars
        principal = bound(principal, 1e18, 1_000_000e18);
        borrowerAprPct = bound(borrowerAprPct, 2, 10);
        maxDurationYears = bound(maxDurationYears, 1, 50);

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

        assert(expectedTotalPrincipal == borrowing.totalPrincipal());
        assert(expectedTotalDeposits == borrowing.totalDeposits());
        // assert(expectedMaxTotalInterestOwed == borrowing.maxTotalInterestOwed())
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

        // Pay Loan
        console.log("making payment...");
        console.log("- payment:", payment);
        borrowing.payLoan(tokenId, payment);
        console.log("payment made.\n");

        // If loan is paid off, return
        (address borrower, , , , , , , ) = borrowing.loans(tokenId);
        if (borrower == address(0)) {
            console.log("loan paid off.\n");
            return;
        }
    }
}