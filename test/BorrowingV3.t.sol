// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/BorrowingV3.sol";

contract BorrowingV3Test is Test {

    BorrowingV3 borrowing = new BorrowingV3();

    function testStartLoan(uint deposit, uint tokenId, uint principal, uint timeJump, uint payment) external {

        // Bound deposit between 1 and 1 billion // Note: if deposit can be 0, utilization() will throw "div by 0"
        deposit = bound(deposit, 1, 1_000_000_000);

        // Deposit
        borrowing.deposit(deposit);
        
        // Bound principal to deposit
        principal = bound(principal, 0, deposit);

        // Start Loan
        borrowing.startLoan(tokenId, principal);

        // Bound timeJump
        timeJump = bound(timeJump, 0, 365 days);

        // Skip by timeJump
        skip(timeJump);

        // // Calculate expectedInterest
        // (UD60x18 loanRatePerSecond, UD60x18 loanUnpaidPrincipal, , , , , ) = borrowing.loans(tokenId);
        // UD60x18 expectedAccruedRate = loanRatePerSecond.mul(toUD60x18(borrowing.timeDeltaSinceLastPayment(tokenId)));
        // UD60x18 expectedInterest = expectedAccruedRate.mul(loanUnpaidPrincipal);
        // console.log("expectedInterest:", UD60x18.unwrap(expectedInterest));
        // if (expectedInterest.lt(toUD60x18(1))) {
        //     expectedInterest = toUD60x18(1);
        // }

        uint minPayment = borrowing.minimumPayment(tokenId);
        console.log("minPayment:", minPayment);

        // Bound payment between expectedInterest and principal
        payment = bound(payment, minPayment, principal); // Question: can't it be higher than principal?

        // Pay loan
        borrowing.payLoan(tokenId, payment);
    }
}