// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
// import { MAX_UD60x18, log10 } from "@prb/math/UD60x18.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";
import "../src/borrowing/IBorrowing.sol";
import "../src/lending/ILending.sol";
import "../src/state/state/IState.sol";
import "../src/borrowing/Borrowing.sol"; // Note: later, further improve architecture, to be able to remove this import
import "../src/lending/Lending.sol"; // Note: later, further improve architecture, to be able to remove this import

import "forge-std/console.sol";

contract ProtocolTest is Test, DeployScript {

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
                if (IBorrowing(protocol).utilization().lt(toUD60x18(1))) {

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

                    if (Borrowing(protocol).status(tokenId) == IState.Status.Mortgage) {

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
                    if (Borrowing(protocol).status(tokenId) == IState.Status.Default) {

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
                    if (IBorrowing(protocol).status(tokenId) == IState.Status.Foreclosurable) {

                        // Foreclose
                        testForeclose(tokenId, randomness[i]);

                    // If no default
                    } else {
                        console.log("not foreclosurable.\n");
                    }
                }
            }
        }
    }

    function testDeposit(uint amount) private validate {

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
        USDC.approve(address(protocol), amount);

        // Deposit
        vm.prank(borrower);
        console.log("d1");
        ILending(protocol).deposit(amount);
        console.log("d2");
    }

    function testWithdraw(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, IBorrowing(protocol).availableLiquidity());
        
        // Set expectations
        expectedTotalDeposits -= amount;

        // Get withdrawer
        address withdrawer = makeAddr("withdrawer");

        // Give withdrawer tUSDC
        uint expectedTUsdcBurn = Lending(protocol).usdcToTUsdc(amount);
        deal(address(tUSDC), withdrawer, expectedTUsdcBurn);

        // Withdraw
        vm.prank(withdrawer);
        ILending(protocol).withdraw(amount);
    }

    function testStartLoan(uint tokenId, uint randomness) private validate {
        
        // Bound principal
        uint principal = bound(randomness, 0, IBorrowing(protocol).availableLiquidity());

        // Get monthSeconds
        uint monthSeconds = Borrowing(protocol).monthSeconds();

        // Calculate expectedRatePerSecond
        uint yearSeconds = Borrowing(protocol).yearSeconds();
        UD60x18 borrowerApr = IBorrowing(protocol).borrowerApr();
        UD60x18 expectedRatePerSecond = borrowerApr.div(toUD60x18(yearSeconds));

        // Calculate maxMaxDurationMonths
        // uint maxMaxDurationMonths1 = fromUD60x18(log10(MAX_UD60x18).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        // uint maxMaxDurationMonths2 = fromUD60x18(log10(MAX_UD60x18.div(toUD60x18(principal).mul(expectedRatePerSecond))).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        // uint maxMaxDurationMonths = maxMaxDurationMonths1 < maxMaxDurationMonths2 ? maxMaxDurationMonths1 : maxMaxDurationMonths2;
        uint maxMaxDurationMonths = 25 * Borrowing(protocol).yearMonths(); // 25 years = 300 months

        if (maxMaxDurationMonths > 0) {
            
            // Calculate expectedMaxUnpaidInterest
            uint maxDurationMonths = bound(randomness, 1, maxMaxDurationMonths);
            uint expectedMaxDurationSeconds = maxDurationMonths * monthSeconds;
            UD60x18 expectedPaymentPerSecond = Borrowing(protocol).calculatePaymentPerSecond(principal, expectedRatePerSecond, expectedMaxDurationSeconds);
            uint expectedLoanCost = fromUD60x18(expectedPaymentPerSecond.mul(toUD60x18(expectedMaxDurationSeconds)));
            uint expectedMaxUnpaidInterest = expectedLoanCost - principal;

            // Set expectations
            expectedTotalPrincipal += principal;
            expectedTotalDeposits = expectedTotalDeposits; // Note: shouldn't be changed by startLoan()
            expectedMaxTotalInterestOwed += expectedMaxUnpaidInterest;
            
            // Start Loan
            IBorrowing(protocol).startLoan(tokenId, principal, /* borrowerAprPct, */ maxDurationMonths);
        }
    }

    function testSkip(uint timeJump) private validate {

        // Bound timeJump (between 0 and 6 months)
        timeJump = bound(timeJump, 0, 6 * 30 days);

        // Skip by timeJump
        skip(timeJump);
    }

    function testPayLoan(uint tokenId, uint payment) private validate {
        
        // Get unpaidPrincipal & interest
        State.Loan memory loan = State(protocol).loans(tokenId);
        uint expectedInterest = Borrowing(protocol).accruedInterest(tokenId);

        // Calculate minPayment & maxPayment
        uint minPayment = expectedInterest;
        uint maxPayment = loan.unpaidPrincipal + expectedInterest;

        // Bound payment
        payment = bound(payment, minPayment, maxPayment);

        // Calculate expectations
        uint expectedRepayment = payment - expectedInterest;
        expectedTotalPrincipal -= expectedRepayment;
        expectedTotalDeposits += expectedInterest;
        expectedMaxTotalInterestOwed -= expectedInterest;

        // Pay Loan
        totalPaidInterest += expectedInterest;
        IBorrowing(protocol).payLoan(tokenId, payment);

        // If loan is paid off, return
        loan = State(protocol).loans(tokenId);
        if (loan.borrower == address(0)) {
            console.log("loan paid off.\n");
        }
    }

    function testRedeem(uint tokenId) private {

        // If default
        // if (protocol.defaulted(tokenId)) {
            
            // // Get redeemer & unpaidPrincipal
            State.Loan memory loan = State(protocol).loans(tokenId);
            uint accruedInterest = Borrowing(protocol).accruedInterest(tokenId);
            uint expectedRedeemerDebt = loan.unpaidPrincipal + accruedInterest;
            uint expectedRedemptionFee = fromUD60x18(toUD60x18(expectedRedeemerDebt).mul(Borrowing(protocol).redemptionFeeSpread()));

            // Give redeemer expectedRedeemerDebt
            deal(address(USDC), loan.borrower, expectedRedeemerDebt + expectedRedemptionFee);

            // Redeemer approves protocol
            vm.prank(loan.borrower);
            USDC.approve(address(protocol), expectedRedeemerDebt + expectedRedemptionFee);
            
            expectedTotalPrincipal -= loan.unpaidPrincipal;
            expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
            expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

            // Redemer redeems
            vm.prank(loan.borrower);
            IBorrowing(protocol).redeem(tokenId);

        // } else {
        //     console.log("no default.\n");
        // }
    }

    function testForeclose(uint tokenId, uint salePrice) private {

        // Get unpaidPrincipal & maxUnpaidInterest
        State.Loan memory loan = Borrowing(protocol).loans(tokenId);

        // Bound salePrice
        uint expectedDefaulterDebt = loan.unpaidPrincipal + Borrowing(protocol).accruedInterest(tokenId);
        uint expectedForeclosureFee = fromUD60x18(toUD60x18(expectedDefaulterDebt).mul(State(protocol).foreclosureFeeSpread()));
        salePrice = bound(salePrice, expectedDefaulterDebt + expectedForeclosureFee, 1_000_000_000 * 1e18);

        uint protocolUsdc = USDC.balanceOf(address(protocol));
        deal(address(USDC), address(protocol), protocolUsdc + salePrice, true);

        expectedTotalPrincipal -= loan.unpaidPrincipal;
        expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
        expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

        // Foreclose
        IBorrowing(protocol).foreclose(tokenId, salePrice);
    }

    modifier validate {
        
        // Run
        _;

        // Validate expectations
        assert(expectedTotalPrincipal == Borrowing(protocol).totalPrincipal());
        assert(expectedTotalDeposits == Borrowing(protocol).totalDeposits());
        assert(expectedMaxTotalInterestOwed == Borrowing(protocol).maxTotalUnpaidInterest());
        console.log("v3");
        // assert(totalPaidInterest <= protocol.maxTotalInterestOwed());
        console.log("v4");

        // Validate lenderApy
        UD60x18 lenderApy = IBorrowing(protocol).lenderApy();
        console.log("v5");
        assert(lenderApy.gte(toUD60x18(0)) /*&& lenderApy.lte(toUD60x18(1))*/); // Note: actually, lenderApy might be able to surpass 100%
        console.log("v6");

        // Validate utilization
        UD60x18 utilization = IBorrowing(protocol).utilization();
        console.log("v7");
        assert(utilization.gte(toUD60x18(0)) && utilization.lte(toUD60x18(1)));
        console.log("v8");
    }
}