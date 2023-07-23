// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

// Protocol Contracts
import "../contracts/protocol/borrowing/IBorrowing.sol";
import "../contracts/protocol/lending/ILending.sol";
import "../contracts/protocol/state/state/IState.sol";
// import "../contracts/protocol/borrowing/borrowing/Borrowing.sol"; // Note: later, further improve architecture, to be able to remove this import
import "../contracts/protocol/lending/Lending.sol"; // Note: later, further improve architecture, to be able to remove this import

// Other
// import { MAX_UD60x18, log10 } from "@prb/math/src/UD60x18.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

import "forge-std/console.sol";

contract ProtocolTest is Test, DeployScript {

    // Actions
    enum Action {
        Deposit, Withdraw, // Lenders
        StartLoan, // Admin
        PayLoan, RedeemLoan, // Borrower In-Loan
        SkipTime // Util
    }
    
    // Expectation Vars
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;
    uint expectedMaxTotalInterestOwed;

    // Other vars
    uint loanCount;
    uint totalPaidInterest;
    uint eResidents;

    // Main
    function testMath(uint[] calldata randomness) public {

        console.log("testMath");

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Deposit)) {
                console.log("\nAction.Deposit");
                testDeposit(randomness[i]);

            } else if (action == uint(Action.Withdraw)) {
                console.log("\nAction.Withdraw");
                testWithdraw(randomness[i]);
            } else if (action == uint(Action.StartLoan)) {
                console.log("\nAction.StartLoan");
                testWithdraw(randomness[i]);
            
            } else if (action == uint(Action.PayLoan)) {
                console.log("\nAction.PayLoan");
                testPayLoan(randomness[i]);

            } else if (action == uint(Action.RedeemLoan)) {
                console.log("\nAction.RedeemLoan");
                testRedeemLoan(randomness[i]);

            } else if (action == uint(Action.SkipTime)) {
                console.log("\nAction.SkipTime");
                testSkip(randomness[i]);
            }
        }
    }

    // Lender
    function testDeposit(uint amount) private {

        // Bound amount
        amount = bound(amount, 0, 1_000_000_000e18);

        _testDeposit(amount);
    }

    function _testDeposit(uint amount) private validate {

        // Set expectations
        expectedTotalDeposits += amount;

        // Get depositor
        address depositor = makeAddr("depositor"); // Todo: later have different depositors

        // Give USDC to depositor
        deal(address(USDC), depositor, amount);

        // Approve protocol to pull amount
        vm.prank(depositor);
        USDC.approve(address(protocol), amount);

        // Depositor deposits
        vm.prank(depositor);
        ILending(protocol).deposit(amount);
    }

    function testWithdraw(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, IInfo(protocol).availableLiquidity()); // Todo: later check user's tUSDC balance so tests have multiple depositors
        
        // Set expectations
        expectedTotalDeposits -= amount;

        // Get withdrawer
        address withdrawer = makeAddr("withdrawer"); // Todo: later have different withdrawers

        // Give withdrawer tUSDC
        uint expectedTUsdcBurn = Lending(protocol).usdcToTUsdc(amount);
        deal(address(tUSDC), withdrawer, expectedTUsdcBurn);

        // Withdraw
        vm.prank(withdrawer);
        ILending(protocol).withdraw(amount);
    }

    // Admin
    function testStartLoan(uint randomness) external {

        console.log("a");

        address borrower = makeAddr("borrower");
        // address seller = makeAddr("seller");
        uint tokenId = 0;
        uint propertyValue = bound(randomness, 50_000e18, 1_000_000_000e18);
        uint downPayment = propertyValue / 2; // Todo: implement different LTVs later
        uint maxDurationMonths = bound(randomness, 12, 240); // 1 to 20 years;

        // Give downPayment to borrower
        vm.prank(borrower);
        deal(address(USDC), borrower, downPayment);

        // Borrower approves protocol
        vm.prank(borrower);
        USDC.approve(address(protocol), downPayment);

        // Ensure protocol has enough funds
        uint protocolBalance = USDC.balanceOf(address(protocol));
        uint loan = propertyValue - downPayment;
        if (protocolBalance < loan) {
            _testDeposit(loan - protocolBalance);
        }

        // Start Loan
        IBorrowing(protocol).startLoan(
            borrower,
            tokenId,
            propertyValue,
            downPayment,
            maxDurationMonths
        );
    }

    // Borrower In-Loan 
    function testPayLoan(uint randomness) private validate {

        console.log("tpl1");

        // Get loansTokenIdsLength
        uint loansTokenIdsLength = IInfo(protocol).loansTokenIdsLength();

        console.log("tpl2");

        // If loans exist
        if (loansTokenIdsLength > 0) {

            console.log("tpl20");

            // Pick randomIdx
            uint randomIdx = randomness % loansTokenIdsLength;

            console.log("tpl21");

            // Get random tokenId
            uint tokenId = IInfo(protocol).loansTokenIdsAt(randomIdx);

            console.log("tpl22");

            // Get status
            IState.Status status = Status(protocol).status(tokenId);

            console.log("tpl23");

            if (status == IState.Status.Mortgage) {

                // Update expectations
                console.log("tpl233");
                uint expectedInterest = IInfo(protocol).accruedInterest(tokenId);
                console.log("tpl238");

                // Pick random payment
                uint payment = bound(randomness, expectedInterest + 1, 1_000_000_000e18);

                uint expectedRepayment = payment - expectedInterest;
                console.log("tpl235");
                IState.Loan memory loan = IInfo(protocol).loans(tokenId);
                if (expectedRepayment > loan.unpaidPrincipal) {
                    expectedRepayment = loan.unpaidPrincipal;
                }
                console.log("tpl236");
                expectedTotalPrincipal -= expectedRepayment;
                console.log("tpl237");
                expectedTotalDeposits += expectedInterest;

                // Get payer
                address payer = makeAddr("payer");

                // Give payment to payer
                deal(address(USDC), payer, payment);

                // Payer approves payment for protocol
                vm.prank(payer);
                USDC.approve(address(protocol), payment);

                // Pay Loan
                vm.prank(payer);
                IBorrowing(protocol).payLoan(tokenId, payment);

                console.log("tpl235");
            }

            console.log("tpl3");

        } else {
            console.log("loansTokenIdsLength = 0. no loans exist.");
        }
        
        // Get unpaidPrincipal & interest
        // State.Loan memory loan = State(protocol).loans(tokenId);
        // uint expectedInterest = Borrowing(protocol).accruedInterest(tokenId);

        // // Calculate minPayment & maxPayment
        // uint minPayment = expectedInterest;
        // uint maxPayment = loan.unpaidPrincipal + expectedInterest;

        // // Bound payment
        // uint payment = bound(randomness, minPayment, maxPayment);

        // // Calculate expectations
        // uint expectedRepayment = payment - expectedInterest;
        // expectedTotalPrincipal -= expectedRepayment;
        // expectedTotalDeposits += expectedInterest;
        // expectedMaxTotalInterestOwed -= expectedInterest;

        // Pay Loan
        // totalPaidInterest += expectedInterest;
        // IBorrowing(protocol).payLoan(tokenId, payment);
        // IBorrowing(protocol).payLoan(tokenId);

        // // If loan is paid off, return
        // loan = State(protocol).loans(tokenId);
        // if (loan.borrower == address(0)) {
        // console.log("loan paid off.\n");
        // }
    }

    function testRedeemLoan(uint randomness) private validate {

        // console.log(1);

        // // if defaulted loans exist
        // // get tokenId of defaulted loan

        // console.log(2);

        // // If nfts exist
        // if (totalSupply > 0) {

        //     console.log(3);

        //     // Get random tokenId
        //     uint tokenId = bound(randomness, 0, totalSupply - 1);

        //     console.log(4);

        //     // If default
        //     if (Automation(protocol).status(tokenId) == IState.Status.Default) {

        //         console.log(5);

        //         // Get redeemer & unpaidPrincipal
        //         State.Loan memory loan = IInfo(protocol).loans(tokenId);
        //         uint accruedInterest = IInfo(protocol).accruedInterest(tokenId);
        //         uint expectedRedeemerDebt = loan.unpaidPrincipal + accruedInterest;
        //         uint expectedRedemptionFee = convert(convert(expectedRedeemerDebt).mul(IInfo(protocol).redemptionFeeSpread()));

        //         // Give redeemer expectedRedeemerDebt
        //         deal(address(USDC), loan.borrower, expectedRedeemerDebt + expectedRedemptionFee);

        //         // Redeemer approves protocol
        //         vm.prank(loan.borrower);
        //         // USDC.approve(address(protocol), expectedRedeemerDebt + expectedRedemptionFee);
        //         USDC.approve(address(protocol), type(uint).max);
                
        //         // expectedTotalPrincipal -= loan.unpaidPrincipal;
        //         // expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
        //         // expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

        //         // Redemer redeems
        //         vm.prank(loan.borrower);
        //         IBorrowing(protocol).redeemLoan(tokenId);

        //         console.log(6);
        //     }
        // } else {
        //     console.log("no default.\n");
        // }
    }

    // Util
    function testSkip(uint randomness) private validate {

        // Bound timeJump (between 0 and 6 months)
        uint timeJump = bound(randomness, 0, 6 * 30 days);

        // Skip by timeJump
        skip(timeJump);
        // skip(1);
    }

    // Validation Modifiers
    modifier validate {
        
        // Run
        _;

        // Validate expectations
        console.log("v0");
        assert(expectedTotalPrincipal == Borrowing(protocol).totalPrincipal());
        console.log("v1");
        assert(expectedTotalDeposits == Borrowing(protocol).totalDeposits());
        console.log("v2");
        // assert(expectedMaxTotalInterestOwed == Borrowing(protocol).maxTotalUnpaidInterest());
        console.log("v3");
        // assert(totalPaidInterest <= protocol.maxTotalInterestOwed());

        // Validate lenderApy
        console.log("v4");
        UD60x18 lenderApy = IInfo(protocol).lenderApy();
        console.log("v5");
        assert(lenderApy.gte(convert(uint(0))) /*&& lenderApy.lte(convert(1))*/); // Note: actually, lenderApy might be able to surpass 100%

        // Validate utilization
        console.log("v6");
        UD60x18 utilization = IBorrowing(protocol).utilization();
        console.log("v7");
        assert(utilization.gte(convert(uint(0))) && utilization.lte(convert(uint(1))));
        console.log("v8");
        assert(State(protocol).totalPrincipal() <= State(protocol).totalDeposits());
        console.log("v9");
    }
}