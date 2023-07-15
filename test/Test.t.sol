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
        PayLoan, RedeemLoan, // Borrower In-Loan
        Foreclose, // Foreclosure
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
            
            } else if (action == uint(Action.PayLoan)) {
                console.log("\nAction.PayLoan");
                testPayLoan(randomness[i]);

            } else if (action == uint(Action.RedeemLoan)) {
                console.log("\nAction.RedeemLoan");
                testRedeemLoan(randomness[i]);

            } else if (action == uint(Action.Foreclose)) {
                console.log("\nAction.Foreclose");
                testForeclose(randomness[i]);
                
            } else if (action == uint(Action.SkipTime)) {
                console.log("\nAction.SkipTime");
                testSkip(randomness[i]);
            }
        }
    }

    // Lender
    function testDeposit(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, 1_000_000_000);

        // Set expectations
        expectedTotalDeposits += amount;

        // Get lender
        address lender = makeAddr("lender");

        // Give USDC to lender
        deal(address(USDC), lender, amount);

        // Approve protocol to pull amount
        vm.prank(lender);
        USDC.approve(address(protocol), amount);

        // Lender deposits
        vm.prank(lender);
        ILending(protocol).deposit(amount);
    }

    function testWithdraw(uint amount) private validate {

        // Bound amount
        amount = bound(amount, 0, IInfo(protocol).availableLiquidity());
        
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

    // Foreclosure
    function testForeclose(uint randomness) private validate {

        // // if foreclosurable loans exist
        // // get tokenId of foreclosurable loan

        // // Get totalSupply
        // uint totalSupply = nftContract.totalSupply();

        // // If nfts exist
        // if (totalSupply > 0) {

        //     console.log("tf0");

        //     // Get random tokenId
        //     uint tokenId = bound(randomness, 0, totalSupply - 1);

        //     // If foreclosurable
        //     if (Automation(protocol).status(tokenId) == IState.Status.Foreclosurable) {

        //         console.log("tf1");

        //         // Get unpaidPrincipal & maxUnpaidInterest
        //         // State.Loan memory loan = Borrowing(protocol).loans(tokenId);

        //         // // Bound salePrice
        //         // uint expectedDefaulterDebt = loan.unpaidPrincipal + Borrowing(protocol).accruedInterest(tokenId);
        //         // uint expectedForeclosureFee = convert(convert(expectedDefaulterDebt).mul(State(protocol).foreclosureFeeSpread()));
        //         // uint salePrice = bound(randomness, expectedDefaulterDebt + expectedForeclosureFee, 1_000_000_000 * 1e18);

        //         // uint protocolUsdc = USDC.balanceOf(address(protocol));
        //         // deal(address(USDC), address(protocol), protocolUsdc + salePrice, true);

        //         // expectedTotalPrincipal -= loan.unpaidPrincipal;
        //         // expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
        //         // expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

        //         IState.Bid[] memory tokenIdBids = IInfo(protocol).bids(tokenId);
        //         if (tokenIdBids.length > 0) {

        //             // Find highestActionableBidIdx
        //             uint highestActionableBidIdx = Automation(protocol).findHighestActionableBidIdx(tokenId);

        //             console.log("tf2");

        //             // Accept Bid
        //             IAuctions(protocol).acceptBid(tokenId, highestActionableBidIdx);
        //         }
        //     }
        // }
    }

    // Util
    function testSkip(uint randomness) private validate {

        // Bound timeJump (between 0 and 6 months)
        uint timeJump = bound(randomness, 0, 6 * 30 days);

        // Skip by timeJump
        // skip(timeJump);
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