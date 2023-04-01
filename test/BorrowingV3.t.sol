// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/BorrowingV3.sol";

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
            skip(timeJump);

            // Pay Loan (with random payment)
            payLoan(tokenId, randomness[i]);

            // If loan is paid off, return
            (address borrower, , , , , , , ) = borrowing.loans(tokenId);
            if (borrower == address(0)) {
                return;
            }
        }

    }

    function startLoan(uint tokenId, uint principal, uint borrowerAprPct, uint maxDurationYears) private {
        
        // Bound vars
        principal = bound(principal, 0, 1_000_000);
        borrowerAprPct = bound(borrowerAprPct, 2, 10);
        maxDurationYears = bound(maxDurationYears, 1, 50);
        
        // Start Loan
        borrowing.startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);
    }

    function payLoan(uint tokenId, uint payment) private {

        // Bound payment
        // payment = bound(payment, 0, );

        // Pay Loan
        borrowing.payLoan(tokenId, payment);
    }
}