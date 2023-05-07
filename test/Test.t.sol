// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

// Protocol Contracts
import "../src/protocol/borrowing/borrowing/IBorrowing.sol";
import "../src/protocol/lending/ILending.sol";
import "../src/protocol/state/state/IState.sol";
// import "../src/protocol/borrowing/borrowing/Borrowing.sol"; // Note: later, further improve architecture, to be able to remove this import
import "../src/protocol/borrowing/automation/Automation.sol"; // Note: later, further improve architecture, to be able to remove this import
import "../src/protocol/lending/Lending.sol"; // Note: later, further improve architecture, to be able to remove this import

// Other
// import { MAX_UD60x18, log10 } from "@prb/math/UD60x18.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract ProtocolTest is Test, DeployScript {

    // Actions
    enum Action {
        Deposit, Withdraw, // Lenders
        Bid, CancelBid, // Borrower Pre-Loan
        AcceptBid, // Seller
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

    function makeActionableBid(uint tokenId, uint randomness, address bidder) private {

        console.log("makeActionableBid");

        // Calculate random propertyValue 
        uint propertyValue = bound(randomness, 10_000e18, 1_000_000_000e18); // 10k to 1B

        // Calculate random downPayment
        uint downPayment = bound(randomness, propertyValue / 2, propertyValue); // for now, do min = max/2 (cause maxLtv is 50%)

        // Pick random maxDurationMonths
        uint maxDurationMonths = bound(randomness, 1, State(protocol).maxDurationMonthsCap());

        console.log("z1");

        // If downPayment < propertyValue
        if (downPayment < propertyValue) {

            // Get availableLiquidity
            uint availableLiquidity = IState(protocol).availableLiquidity();

            console.log("z2");

            // If downPayment > availableLiquidity
            if (downPayment > availableLiquidity) {

                console.log("z3");
                
                // Calculate neededLiquidity
                uint neededLiquidity = downPayment - availableLiquidity;

                console.log("z4");

                // Get lender
                address lender = makeAddr("lender");

                // Give neededLiquidity to lender
                deal(address(USDC), lender, neededLiquidity);

                console.log("z5");

                // Lender approve protocol to pull neededLiquidity
                vm.prank(lender);
                USDC.approve(address(protocol), neededLiquidity);

                // Lender seposits neededLiquidity
                vm.prank(lender);
                ILending(protocol).deposit(neededLiquidity);

                // Update expectedTotalDeposits
                expectedTotalDeposits += neededLiquidity;

                console.log("z6");
            }
        }

        // Give bidder downPayment
        deal(address(USDC), bidder, downPayment);

        console.log("z7");

        // If bidder not eResident
        if (!nftContract.isEResident(bidder)) {

            // Verify bidder
            eResidents ++;
            nftContract.verifyEResident(eResidents, bidder);
        }

        // Bidder approves protocol
        vm.prank(bidder);
        USDC.approve(protocol, downPayment);

        console.log("z8");

        // Bidder bids
        vm.prank(bidder);
        IAuctions(protocol).bid(tokenId, propertyValue, downPayment, maxDurationMonths);

        console.log("z9");
    }

    function makeBid(uint tokenId, uint randomness, address bidder) private {

        console.log("makeBid");

        // Calculate random propertyValue 
        uint propertyValue = bound(randomness, 10_000e18, 1_000_000_000e18); // 10k to 1B

        // Calculate random downPayment
        uint downPayment = bound(randomness, propertyValue / 2, propertyValue); // for now, do min = max/2 (cause maxLtv is 50%)

        // Pick random maxDurationMonths
        uint maxDurationMonths = bound(randomness, 1, State(protocol).maxDurationMonthsCap());

        // Give bidder downPayment
        deal(address(USDC), bidder, downPayment);

        // If bidder not eResident
        if (!nftContract.isEResident(bidder)) {

            // Verify bidder
            eResidents ++;
            nftContract.verifyEResident(eResidents, bidder);
        }

        // Bidder approves protocol
        vm.prank(bidder);
        USDC.approve(protocol, downPayment);

        // Bidder bids
        vm.prank(bidder);
        IAuctions(protocol).bid(tokenId, propertyValue, downPayment, maxDurationMonths);
    }

    // Setup
    function setUp() public {

        uint desiredSupply = 100;
        string memory defaultTokenURI = "";

        // Loop desiredSupply
        for (uint i = 1; i <= desiredSupply; i++) { // loop vars unusual because i can't be 0

            console.log("i:", i);

            // Get nftOwner
            address nftOwner = vm.addr(i); // doesn't work if i = 0

            // KYC nftOwner
            eResidents ++;
            nftContract.verifyEResident(eResidents, nftOwner);

            // Mint nft to nftOwner
            nftContract.mint(nftOwner, defaultTokenURI);
        }
    }

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

            } else if (action == uint(Action.Bid)) {
                console.log("\nAction.Bid");
                testBid(randomness[i]);

            } else if (action == uint(Action.CancelBid)) {
                console.log("\nAction.CancelBid");
                testCancelBid(randomness[i]);

            } else if (action == uint(Action.AcceptBid)) {
                console.log("\nAction.AcceptBid");
                testAcceptBid(randomness[i]);
            
            } else if (action == uint(Action.PayLoan)) {
                console.log("\nAction.PayLoan");
                testPayLoan(randomness[i]);

            } else if (action == uint(Action.RedeemLoan)) {
                console.log("\nAction.Redeem");
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
        amount = bound(amount, 0, IState(protocol).availableLiquidity());
        
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

    // Borrower Pre-Loan
    function testBid(uint randomness) private validate {

        // Get bidder
        address bidder = makeAddr("bidder");

        // Get random tokenId
        uint tokenId = bound(randomness, 0, nftContract.totalSupply() - 1);

        // Bid
        makeBid({
            tokenId: tokenId,
            randomness: randomness,
            bidder: bidder
        });
    }

    function testCancelBid(uint randomness) private validate {

        // Get totalSupply
        uint totalSupply = nftContract.totalSupply();

        // If nfts exist
        if (totalSupply > 0) {

            // Get random tokenId
            uint tokenId = bound(randomness, 0, totalSupply - 1);

            // Get tokenIdBids
            IState.Bid[] memory tokenIdBids = State(protocol).bids(tokenId);

            // If tokenId has bids
            if (tokenIdBids.length > 0) {
                
                // Get randomIdx
                uint randomIdx = bound(randomness, 0, tokenIdBids.length - 1);

                // Bidder cancels bid
                vm.prank(tokenIdBids[randomIdx].bidder);
                IAuctions(protocol).cancelBid(tokenId, randomIdx);

            } else {
                console.log("tokenId has no bids");
            }

        } else {
            console.log("totalSupply = 0. no nfts exist.");
        }
    }

    // Seller
    function testAcceptBid(uint randomness) private validate {

        // Get totalSupply
        uint totalSupply = nftContract.totalSupply();
        assert(totalSupply > 0);

        // Get random tokenId
        uint tokenId = bound(randomness, 0, totalSupply - 1);

        // Get tokenIdBids
        IState.Bid[] memory tokenIdBids = State(protocol).bids(tokenId);

        uint tokenIdBidIdx;

        // if tokenId has no bids
        if (tokenIdBids.length == 0) {

            // make actionable bid on tokenId // Note: tokenIdBidIdx will be 0 (which is correct with newly added bid)
            makeActionableBid({
                tokenId: tokenId,
                randomness: randomness,
                bidder: makeAddr("bidder")
            });

        } else {

            // Get random tokenIdBidIdx
            tokenIdBidIdx = randomness % tokenIdBids.length;

            // Get Bid
            IState.Bid memory _bid = tokenIdBids[tokenIdBidIdx];

            // If bid isn't actionable
            if (!State(protocol).bidActionable(_bid)) {

                // make actionable bid on tokenId
                makeActionableBid({
                    tokenId: tokenId,
                    randomness: randomness,
                    bidder: makeAddr("bidder")
                });

                // Update tokenIdBidIdx
                tokenIdBidIdx = tokenIdBids.length; // Note: length will increase by 1, so idx of new bid will be prev length
            }
        }

        // Get status
        IState.Status status = Status(protocol).status(tokenId);

        console.log("zz1");

        // Update expectedTotalPrincipal // Note: do it before acceptBid() (because bid will be deleted after it's accepted)
        IState.Bid memory bid = State(protocol).bids(tokenId)[tokenIdBidIdx];
        uint expectedPrincipal = bid.propertyValue - bid.downPayment;
        expectedTotalPrincipal += expectedPrincipal;

        console.log("zz2");

        // If status == None
        if (status == IState.Status.None) {

            // Get nftOwner
            address nftOwner = nftContract.ownerOf(tokenId);

            // NftOwner approves protocol
            vm.prank(nftOwner);
            nftContract.approve(protocol, tokenId);

            // Nft Owner Accepts Bid
            vm.prank(nftOwner);
            IAuctions(protocol).acceptBid(tokenId, tokenIdBidIdx);
        
        // If status == Mortgage or Default
        } else if (status == IState.Status.Mortgage || status == IState.Status.Default) {
            
            // Get loan
            IState.Loan memory loan = Status(protocol).loans(tokenId);

            // Update expectations
            expectedTotalPrincipal -= loan.unpaidPrincipal;
            expectedTotalDeposits += Status(protocol).accruedInterest(tokenId);

            // Borrower Accepts Bid
            vm.prank(loan.borrower);
            IAuctions(protocol).acceptBid(tokenId, tokenIdBidIdx);

        // If status == Foreclosurable
        } else if (status == IState.Status.Foreclosurable) {

            // Get loan
            IState.Loan memory loan = Status(protocol).loans(tokenId);

            // Update expectations
            expectedTotalPrincipal -= loan.unpaidPrincipal;
            expectedTotalDeposits += Status(protocol).accruedInterest(tokenId);

            // Accepts Bid
            IAuctions(protocol).acceptBid(tokenId, tokenIdBidIdx);
        }

        console.log("ble");
        
        // // Bound principal
        // uint principal = bound(randomness, 0, IState(protocol).availableLiquidity());

        // // Get monthSeconds
        // uint monthSeconds = Borrowing(protocol).monthSeconds();

        // // Calculate expectedRatePerSecond
        // uint yearSeconds = Borrowing(protocol).yearSeconds();
        // UD60x18 borrowerApr = IBorrowing(protocol).borrowerApr();
        // UD60x18 expectedRatePerSecond = borrowerApr.div(toUD60x18(yearSeconds));

        // // Calculate maxMaxDurationMonths
        // // uint maxMaxDurationMonths1 = fromUD60x18(log10(MAX_UD60x18).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        // // uint maxMaxDurationMonths2 = fromUD60x18(log10(MAX_UD60x18.div(toUD60x18(principal).mul(expectedRatePerSecond))).div(toUD60x18(monthSeconds).mul(log10(toUD60x18(1).add(expectedRatePerSecond))))); // Note: explained in calculatePaymentPerSecond()
        // // uint maxMaxDurationMonths = maxMaxDurationMonths1 < maxMaxDurationMonths2 ? maxMaxDurationMonths1 : maxMaxDurationMonths2;
        // uint maxMaxDurationMonths = 25 * Borrowing(protocol).yearMonths(); // 25 years = 300 months

        // if (maxMaxDurationMonths > 0) {
            
        //     // Calculate expectedMaxUnpaidInterest
        //     uint maxDurationMonths = bound(randomness, 1, maxMaxDurationMonths);
        //     uint expectedMaxDurationSeconds = maxDurationMonths * monthSeconds;
        //     UD60x18 expectedPaymentPerSecond = Borrowing(protocol).calculatePaymentPerSecond(principal, expectedRatePerSecond, expectedMaxDurationSeconds);
        //     uint expectedLoanCost = fromUD60x18(expectedPaymentPerSecond.mul(toUD60x18(expectedMaxDurationSeconds)));
        //     uint expectedMaxUnpaidInterest = expectedLoanCost - principal;

        //     // Set expectations
        //     expectedTotalPrincipal += principal;
        //     expectedTotalDeposits = expectedTotalDeposits; // Note: shouldn't be changed by startLoan()
        //     expectedMaxTotalInterestOwed += expectedMaxUnpaidInterest;
            
        //     // Start Loan
        //     IBorrowing(protocol).startLoan(tokenId, principal, /* borrowerAprPct, */ maxDurationMonths);
        // }
    }

    // Borrower In-Loan 
    function testPayLoan(uint randomness) private validate {

        console.log("tpl1");

        // Get loansTokenIdsLength
        uint loansTokenIdsLength = State(protocol).loansTokenIdsLength();

        console.log("tpl2");

        // If loans exist
        if (loansTokenIdsLength > 0) {

            console.log("tpl20");

            // Pick randomIdx
            uint randomIdx = randomness % loansTokenIdsLength;

            console.log("tpl21");

            // Get random tokenId
            uint tokenId = State(protocol).loansTokenIdsAt(randomIdx);

            console.log("tpl22");

            // Get status
            IState.Status status = Status(protocol).status(tokenId);

            console.log("tpl23");

            if (status == IState.Status.Mortgage) {

                // Update expectations
                console.log("tpl233");
                uint expectedInterest = State(protocol).accruedInterest(tokenId);
                console.log("tpl238");

                // Pick random payment
                uint payment = bound(randomness, expectedInterest + 1, 1_000_000_000e18);

                uint expectedRepayment = payment - expectedInterest;
                console.log("tpl235");
                IState.Loan memory loan = State(protocol).loans(tokenId);
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

        console.log(1);

        // if defaulted loans exist
        // get tokenId of defaulted loan

        // Get totalSupply
        uint totalSupply = nftContract.totalSupply();

        console.log(2);

        // If nfts exist
        if (totalSupply > 0) {

            console.log(3);

            // Get random tokenId
            uint tokenId = bound(randomness, 0, totalSupply - 1);

            console.log(4);

            // If default
            if (Automation(protocol).status(tokenId) == IState.Status.Default) {

                console.log(5);

                // Get redeemer & unpaidPrincipal
                State.Loan memory loan = State(protocol).loans(tokenId);
                uint accruedInterest = Borrowing(protocol).accruedInterest(tokenId);
                uint expectedRedeemerDebt = loan.unpaidPrincipal + accruedInterest;
                uint expectedRedemptionFee = fromUD60x18(toUD60x18(expectedRedeemerDebt).mul(Borrowing(protocol).redemptionFeeSpread()));

                // Give redeemer expectedRedeemerDebt
                deal(address(USDC), loan.borrower, expectedRedeemerDebt + expectedRedemptionFee);

                // Redeemer approves protocol
                vm.prank(loan.borrower);
                USDC.approve(address(protocol), expectedRedeemerDebt + expectedRedemptionFee);
                
                // expectedTotalPrincipal -= loan.unpaidPrincipal;
                // expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
                // expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

                // Redemer redeems
                // vm.prank(loan.borrower);
                IBorrowing(protocol).redeemLoan(tokenId);

                console.log(6);

                require(false, "testRedeemLoan");
            }
        } else {
            console.log("no default.\n");
        }
    }

    // Foreclosure
    function testForeclose(uint randomness) private validate {

        // if foreclosurable loans exist
        // get tokenId of foreclosurable loan

        // Get totalSupply
        uint totalSupply = nftContract.totalSupply();

        // If nfts exist
        if (totalSupply > 0) {

            console.log("tf0");

            // Get random tokenId
            uint tokenId = bound(randomness, 0, totalSupply - 1);

            // If foreclosurable
            if (Automation(protocol).status(tokenId) == IState.Status.Foreclosurable) {

                console.log("tf1");

                // Get unpaidPrincipal & maxUnpaidInterest
                // State.Loan memory loan = Borrowing(protocol).loans(tokenId);

                // // Bound salePrice
                // uint expectedDefaulterDebt = loan.unpaidPrincipal + Borrowing(protocol).accruedInterest(tokenId);
                // uint expectedForeclosureFee = fromUD60x18(toUD60x18(expectedDefaulterDebt).mul(State(protocol).foreclosureFeeSpread()));
                // uint salePrice = bound(randomness, expectedDefaulterDebt + expectedForeclosureFee, 1_000_000_000 * 1e18);

                // uint protocolUsdc = USDC.balanceOf(address(protocol));
                // deal(address(USDC), address(protocol), protocolUsdc + salePrice, true);

                // expectedTotalPrincipal -= loan.unpaidPrincipal;
                // expectedTotalDeposits += Borrowing(protocol).accruedInterest(tokenId);
                // expectedMaxTotalInterestOwed -= loan.maxUnpaidInterest;

                IState.Bid[] memory tokenIdBids = IState(protocol).bids(tokenId);
                if (tokenIdBids.length > 0) {

                    // Find highestActionableBidIdx
                    uint highestActionableBidIdx = Automation(protocol).findHighestActionableBidIdx(tokenId);

                    console.log("tf2");

                    // Accept Bid
                    IAuctions(protocol).acceptBid(tokenId, highestActionableBidIdx);
                }
            }
        }
    }

    // Util
    function testSkip(uint randomness) private validate {

        // Bound timeJump (between 0 and 6 months)
        uint timeJump = bound(randomness, 0, 6 * 30 days);

        // Skip by timeJump
        skip(timeJump);
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
        UD60x18 lenderApy = IBorrowing(protocol).lenderApy();
        console.log("v5");
        assert(lenderApy.gte(toUD60x18(0)) /*&& lenderApy.lte(toUD60x18(1))*/); // Note: actually, lenderApy might be able to surpass 100%

        // Validate utilization
        console.log("v6");
        UD60x18 utilization = IBorrowing(protocol).utilization();
        console.log("v7");
        assert(utilization.gte(toUD60x18(0)) && utilization.lte(toUD60x18(1)));
        console.log("v8");
        assert(State(protocol).totalPrincipal() <= State(protocol).totalDeposits());
        console.log("v9");
    }
}