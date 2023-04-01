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
        console.log("starting loan...");
        startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);
        console.log("loan started.\n");

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
                console.log("making payment...");
                payLoan(tokenId, randomness[i]);
                console.log("payment made.\n");

            } else {
                console.log("defaulted.\n");
                return;
            }

            // If loan is paid off, return
            (address borrower, , , , , , , ) = borrowing.loans(tokenId);
            if (borrower == address(0)) {
                console.log("loan paid off.\n");
                return;
            }
        }

    }

    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) private {
        
        // Bound vars
        principal = bound(principal, 1e18, 1_000_000e18);
        borrowerAprPct = bound(borrowerAprPct, 2, 10);
        maxDurationYears = bound(maxDurationYears, 1, 50);

        // console.log("s1");
        
        // Start Loan
        borrowing.startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);

        // console.log("s2");
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

        console.log("p1");

        // Pay Loan
        borrowing.payLoan(tokenId, payment);

        console.log("p2");
    }
}