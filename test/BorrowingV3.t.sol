// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

contract BorrowingV3Test is Test, DeployScript {

    // Actions
    enum Action { Deposit, Withdraw, Start, Pay, Skip }
    
    // Expectation Vars
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;
    uint expectedMaxTotalInterestOwed;

    // Other vars
    uint loanCount;
    uint totalPaidInterest;
    // uint yearSeconds = borrowing.yearSeconds();

    function testMath(uint[] calldata randomness) public {

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Deposit)) {

                // Deposit
                deposit(randomness[i]);

            } else if (action == uint(Action.Withdraw)) {

                // Withdraw
                withdraw(randomness[i]);

            } else if (action == uint(Action.Start)) {
                
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

                    if (!borrowing.defaulted(tokenId)) {

                        // Pay Loan
                        payLoan(tokenId, randomness[i]);

                    } else {
                        console.log("defaulted.\n");
                    }
                }
            
            // If Skip
            } else if (action == uint(Action.Skip)) {

                // Skip
                skipTime(randomness[i]);
            }
        }
    }

    function deposit(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, 1_000_000_000);

        // Set expectations
        expectedTotalDeposits += amount;

        // Deposit
        console.log("depositing", amount);
        borrowing.deposit(amount);
        console.log("deposit complete.");
    }

    function withdraw(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, borrowing.availableLiquidity());
        
        // Set expectations
        expectedTotalDeposits -= amount;

        // Withdraw
        console.log("withdrawing", amount);
        borrowing.withdraw(amount);
        console.log("withdrawal complete.");
    }

    function startLoan(uint tokenId, uint randomness) private validate {
        
        // Bound vars
        uint principal = bound(randomness, 0, borrowing.availableLiquidity());
        uint borrowerAprPct = bound(randomness, 2, 10);
        uint maxDurationYears = bound(randomness, 1, 50);

        // Calculate expectedMaxUnpaidInterest
        uint yearSeconds = borrowing.yearSeconds();
        UD60x18 expectedRatePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));
        uint expectedMaxDurationSeconds = maxDurationYears * yearSeconds;
        UD60x18 expectedPaymentPerSecond = borrowing.calculatePaymentPerSecond(principal, expectedRatePerSecond, expectedMaxDurationSeconds);
        uint expectedLoanCost = fromUD60x18(expectedPaymentPerSecond.mul(toUD60x18(expectedMaxDurationSeconds)));
        uint expectedMaxUnpaidInterest = expectedLoanCost - principal;

        // Set expectations
        expectedTotalPrincipal += principal;
        expectedTotalDeposits = expectedTotalDeposits; // Note: shouldn't be changed by startLoan()
        expectedMaxTotalInterestOwed += expectedMaxUnpaidInterest;
        
        // Start Loan
        console.log("starting loan...");
        console.log("- principal:", principal);
        console.log("- borrowerAprPct:", borrowerAprPct);
        console.log("- maxDurationYears:", maxDurationYears);
        borrowing.startLoan(tokenId, principal, borrowerAprPct, maxDurationYears);
        console.log("loan started.\n");
    }

    function skipTime(uint timeJump) private validate {

        // Bound timeJump (between 0 and 6 months)
        timeJump = bound(timeJump, 0, 6 * 30 days);

        // Skip by timeJump
        console.log("skipping time by", timeJump);
        skip(timeJump);
        console.log("time skipped.\n");
    }

    function payLoan(uint tokenId, uint payment) private validate {
        
        // Get unpaidPrincipal & interest
        (, , , , uint unpaidPrincipal, , , ) = borrowing.loans(tokenId);
        uint expectedInterest = borrowing.accruedInterest(tokenId);

        // Calculate minPayment & maxPayment
        uint minPayment = expectedInterest;
        uint maxPayment = unpaidPrincipal + expectedInterest;

        // Bound payment
        payment = bound(payment, minPayment, maxPayment);

        // Calculate expectations
        uint expectedRepayment = payment - expectedInterest;
        expectedTotalPrincipal -= expectedRepayment;
        expectedTotalDeposits += expectedInterest;
        expectedMaxTotalInterestOwed -= expectedInterest;

        // Pay Loan
        console.log("making payment...");
        console.log("- payment:", payment);
        totalPaidInterest += expectedInterest;
        borrowing.payLoan(tokenId, payment);
        console.log("payment made.\n");

        // If loan is paid off, return
        (address borrower, , , , , , , ) = borrowing.loans(tokenId);
        if (borrower == address(0)) {
            console.log("loan paid off.\n");
        }
    }

    modifier validate() {
        
        // Run
        _;

        // Validate expectations
        assert(expectedTotalPrincipal == borrowing.totalPrincipal());
        assert(expectedTotalDeposits == borrowing.totalDeposits());
        assert(expectedMaxTotalInterestOwed == borrowing.maxTotalInterestOwed());
        assert(totalPaidInterest <= borrowing.maxTotalInterestOwed());

        // Validate lenderApy
        UD60x18 lenderApy = borrowing.lenderApy();
        assert(lenderApy.gte(toUD60x18(0)) /*&& lenderApy.lte(toUD60x18(1))*/); // Note: actually, lenderApy might be able to surpass 100%

        // Validate utilization
        UD60x18 utilization = borrowing.utilization();
        assert(utilization.gte(toUD60x18(0)) && utilization.lte(toUD60x18(1)));
    }
}