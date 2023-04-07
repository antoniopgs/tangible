// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import { MAX_UD60x18, log10 } from "@prb/math/UD60x18.sol";

import "forge-std/console.sol";

contract BorrowingV3Test is Test, DeployScript {

    // Actions
    enum Action { Deposit, Withdraw, StartLoan, PayLoan, SkipTime, Redeem, Foreclose }
    
    // Expectation Vars
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;
    uint expectedMaxTotalInterestOwed;

    // Other vars
    uint loanCount;
    uint totalPaidInterest;

    function testMath(uint[] calldata randomness) public {

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Deposit)) {

                console.log("\nAction.Deposit");

                // Deposit
                testDeposit(randomness[i]);

            } else if (action == uint(Action.Withdraw)) {

                console.log("\nAction.Withdraw");

                // Withdraw
                testWithdraw(randomness[i]);

            } else if (action == uint(Action.StartLoan)) {

                console.log("\nAction.StartLoan");

                // If utilization < 100% (can't startLoan otherwise)
                if (borrowing.utilization().lt(toUD60x18(1))) {

                    // Set tokenId
                    uint tokenId = loanCount;

                    // Start Loan
                    testStartLoan(tokenId, randomness[i]);

                    // Increment loanCount
                    loanCount++;
                }
            
            // If Pay
            } else if (action == uint(Action.PayLoan)) {

                console.log("\nAction.PayLoan");
                
                // If loans exist
                if (loanCount > 0) {

                    // Get random tokenId
                    uint tokenId = randomness[i] % loanCount;

                    if (!borrowing.defaulted(tokenId)) {

                        // Pay Loan
                        testPayLoan(tokenId, randomness[i]);

                    } else {
                        console.log("defaulted.\n");
                    }
                }
            
            // If Skip
            } else if (action == uint(Action.SkipTime)) {

                console.log("\nAction.SkipTime");

                // Skip
                testSkip(randomness[i]);

            } else if (action == uint(Action.Redeem)) {

                console.log("\nAction.Redeem");

                // If loans exist
                if (loanCount > 0) {

                    // Get random tokenId
                    uint tokenId = randomness[i] % loanCount;

                    // If default
                    if (borrowing.state(tokenId) == BorrowingV3.State.Default) {

                        // Redeem
                        testRedeem(tokenId);
                    
                    // If no default
                    } else {
                        console.log("no default.\n");
                    }
                }

            } else if (action == uint(Action.Foreclose)) {

                console.log("\nAction.Foreclose");

                // If loans exist
                if (loanCount > 0) {

                    // Get random tokenId
                    uint tokenId = randomness[i] % loanCount;

                    // If default
                    if (borrowing.state(tokenId) == BorrowingV3.State.Default) {

                        // Foreclose
                        testForeclose(tokenId, randomness[i]);

                    // If no default
                    } else {
                        console.log("no default.\n");
                    }
                }
            }
        }
    }

    function testDeposit(uint amount) private validate {
        console.log("block.timestamp:", block.timestamp);

        // Bound amount
        amount = bound(amount, 0, 1_000_000_000);

        // Set expectations
        expectedTotalDeposits += amount;

        // Get borrower
        address borrower = makeAddr("borrower");

        // Give USDC to borrower
        deal(address(USDC), borrower, amount);

        // Approve protocol to pull amount
        vm.prank(borrower);
        USDC.approve(address(borrowing), amount);

        // Deposit
        vm.prank(borrower);
        console.log("depositing", amount);
        borrowing.deposit(amount);
        console.log("deposit complete.");
    }

    function testWithdraw(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, borrowing.availableLiquidity());
        
        // Set expectations
        expectedTotalDeposits -= amount;

        // Get withdrawer
        address withdrawer = makeAddr("withdrawer");

        // Give withdrawer tUSDC
        uint expectedTUsdcBurn = borrowing.usdcToTUsdc(amount);
        deal(address(tUSDC), withdrawer, expectedTUsdcBurn);

        // Withdraw
        vm.prank(withdrawer);
        borrowing.withdraw(amount);
    }

    function testStartLoan(uint tokenId, uint randomness) private validate {
        console.log("tokenId:", tokenId);
        console.log("block.timestamp:", block.timestamp);
        
        // Bound principal
        uint principal = bound(randomness, 0, borrowing.availableLiquidity());

        console.log("ts1");

        // Get monthSeconds
        uint monthSeconds = borrowing.monthSeconds();

        console.log("ts2");

        // Calculate expectedRatePerSecond
        uint yearSeconds = borrowing.yearSeconds();
        UD60x18 borrowerApr = borrowing.borrowerApr();
        UD60x18 expectedRatePerSecond = borrowerApr.div(toUD60x18(yearSeconds));

        console.log("ts3");

        // Calculate maxMaxDurationMonths
        uint maxMaxDurationMonths1 = fromUD60x18(log10(MAX_UD60x18).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        uint maxMaxDurationMonths2 = fromUD60x18(log10(MAX_UD60x18.div(toUD60x18(principal).mul(expectedRatePerSecond))).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        uint maxMaxDurationMonths = maxMaxDurationMonths1 < maxMaxDurationMonths2 ? maxMaxDurationMonths1 : maxMaxDurationMonths2;

        console.log("ts4");

        if (maxMaxDurationMonths > 0) {
            
            // Calculate expectedMaxUnpaidInterest
            console.log("ts5");
            uint maxDurationMonths = bound(randomness, 1, maxMaxDurationMonths);
            console.log("ts6");
            uint expectedMaxDurationSeconds = maxDurationMonths * monthSeconds;
            console.log("ts7");
            UD60x18 expectedPaymentPerSecond = borrowing.calculatePaymentPerSecond(principal, expectedRatePerSecond, expectedMaxDurationSeconds);
            console.log("ts8");
            uint expectedLoanCost = fromUD60x18(expectedPaymentPerSecond.mul(toUD60x18(expectedMaxDurationSeconds)));
            console.log("ts9");
            uint expectedMaxUnpaidInterest = expectedLoanCost - principal;
            console.log("ts10");

            // Set expectations
            expectedTotalPrincipal += principal;
            expectedTotalDeposits = expectedTotalDeposits; // Note: shouldn't be changed by startLoan()
            expectedMaxTotalInterestOwed += expectedMaxUnpaidInterest;
            
            // Start Loan
            console.log("starting loan...");
            console.log("- principal:", principal);
            console.log("- UD60x18.unwrap(borrowerApr):", UD60x18.unwrap(borrowerApr));
            console.log("- maxDurationMonths:", maxDurationMonths);
            borrowing.startLoan(tokenId, principal, /* borrowerAprPct, */ maxDurationMonths);
            console.log("loan started.\n");
        }
    }

    function testSkip(uint timeJump) private validate {

        // Bound timeJump (between 0 and 6 months)
        timeJump = bound(timeJump, 0, 6 * 30 days);

        // Skip by timeJump
        console.log("skipping time by", timeJump);
        skip(timeJump);
        console.log("time skipped.\n");
    }

    function testPayLoan(uint tokenId, uint payment) private validate {
        console.log("tokenId:", tokenId);
        console.log("block.timestamp:", block.timestamp);
        
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

    function testRedeem(uint tokenId) private {
        console.log("tokenId:", tokenId);
        console.log("block.timestamp:", block.timestamp);

        // If default
        // if (borrowing.defaulted(tokenId)) {
            
            // // Get redeemer & unpaidPrincipal
            (address redeemer, , , , uint unpaidPrincipal, uint maxUnpaidInterest, , ) = borrowing.loans(tokenId);
            uint accruedInterest = borrowing.accruedInterest(tokenId);
            uint expectedRedeemerDebt = unpaidPrincipal + accruedInterest;

            // Give redeemer expectedRedeemerDebt
            deal(address(USDC), redeemer, expectedRedeemerDebt);

            // Redeemer approves protocol
            vm.prank(redeemer);
            USDC.approve(address(borrowing), expectedRedeemerDebt);

            
            expectedTotalPrincipal -= unpaidPrincipal;
            expectedTotalDeposits += borrowing.accruedInterest(tokenId);
            expectedMaxTotalInterestOwed -= maxUnpaidInterest;

            // Redemer redeems
            vm.prank(redeemer);
            console.log("redeeming...");
            borrowing.redeem(tokenId);
            console.log("redemption complete.");

        // } else {
        //     console.log("no default.\n");
        // }
    }

    function testForeclose(uint tokenId, uint salePrice) private {
        console.log("tokenId:", tokenId);
        console.log("block.timestamp:", block.timestamp);

        // Get unpaidPrincipal & maxUnpaidInterest
        (, , , , uint unpaidPrincipal, uint maxUnpaidInterest, , ) = borrowing.loans(tokenId);

        // Bound salePrice
        uint expectedDefaulterDebt = unpaidPrincipal + borrowing.accruedInterest(tokenId);
        salePrice = bound(salePrice, expectedDefaulterDebt, 1_000_000_000 * 1e18);

        uint protocolUsdc = USDC.balanceOf(address(borrowing));
        deal(address(USDC), address(borrowing), protocolUsdc + salePrice, true);

        expectedTotalPrincipal -= unpaidPrincipal;
        expectedTotalDeposits += borrowing.accruedInterest(tokenId);
        expectedMaxTotalInterestOwed -= maxUnpaidInterest;

        // Foreclose
        console.log("foreclosing...");
        borrowing.foreclose(tokenId, salePrice);
        console.log("foreclosure complete.");
    }

    modifier validate {
        
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