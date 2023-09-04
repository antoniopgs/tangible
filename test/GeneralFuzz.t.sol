// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";

// Protocol Contracts
import "../contracts/protocol/borrowing/IBorrowing.sol";
import "../contracts/protocol/interest/Interest.sol";
import "../contracts/protocol/lending/ILending.sol";
import { Status } from "../contracts/types/Types.sol";

// Other
// import { convert } from "@prb/math/src/UD60x18.sol";
import { console } from "forge-std/console.sol";

contract GeneralFuzz is Test, DeployScript {

    // Actions
    enum Action {
        Bid, CancelBid, // Buyers
        AcceptBid, PayMortgage, RedeemMortgage, // Sellers
        Foreclose, // PAC
        Deposit, Withdraw, // Lenders,
        SkipTime // Util
    }
    
    // Expectation Varsx
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;

    uint residentCount;

    // Main
    function testMath(uint[100] calldata randomness) public {
        console.log("testMath...");

        _mintNfts(100);

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Bid)) {
                _testBid(randomness[i]);

            } else if (action == uint(Action.CancelBid)) {
                _testCancelBid(randomness[i]);
                
            } else if (action == uint(Action.AcceptBid)) {
                _testAcceptBid(randomness[i]);

            } else if (action == uint(Action.PayMortgage)) {
                _testPayLoan(randomness[i]);

            } else if (action == uint(Action.RedeemMortgage)) {
                _testRedeemLoan(randomness[i]);
                
            } else if (action == uint(Action.Foreclose)) {
                _testForeclose(randomness[i]);
            
            } else if (action == uint(Action.Deposit)) {
                _testDeposit(randomness[i]);

            } else if (action == uint(Action.Withdraw)) {
                _testWithdraw(randomness[i]);

            } else if (action == uint(Action.SkipTime)) {
                _testSkip(randomness[i]);
            }
        }
    }

    function _testBid(uint randomness) private {
        console.log("\ntestBid...");

        // Bid
        _makeActionableBid(randomness);
    }

    function _testCancelBid(uint randomness) private {
        console.log("\ntestCancelBid...");

        // Bid
        (address bidder, uint tokenId, uint idx) = _makeActionableBid(randomness);

        // Bidder cancels bid
        vm.prank(bidder);
        IAuctions(proxy).cancelBid(tokenId, idx);
    }

    function _testAcceptBid(uint randomness) private {
        console.log("\ntestAcceptBid...");

        // Bid
        (, uint tokenId, uint idx) = _makeActionableBid(randomness); // Todo: ensure bid is actionable later

        // Get seller
        address seller = nftContract.ownerOf(tokenId);

        // Seller accepts bid
        vm.prank(seller);
        IAuctions(proxy).acceptBid(tokenId, idx);
    }

    function _testPayLoan(uint randomness) private {
        console.log("\ntestPayLoan...");

        // Get random tokenId
        uint tokenId = _randomTokenId(randomness);

        // If Mortgage
        if (LoanStatus(proxy).status(tokenId) == Status.Mortgage) {

            // Get payment
            uint payment = bound(randomness, 10e6, 1_000_000_000e6); // Note: USDC has 6 decimals

            // Deal & Approve
            address payee = _randomAddress(randomness);
            deal(address(USDC), payee, payment);
            vm.prank(payee);
            USDC.approve(proxy, payment);

            // Pay loan
            vm.prank(payee);
            IBorrowing(proxy).payMortgage(tokenId, payment);
        }
    }

    function _testRedeemLoan(uint randomness) private {
        console.log("\ntestRedeemLoan...");

        // Make Actionable Loan Bid
        (address bidder, uint tokenId, uint idx) = _makeActionableLoanBid(randomness);

        // Seller accepts bid
        vm.prank(nftContract.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Skip time (to make redeemable)
        skip(30 days + 15 days);

        uint unpaidPrincipal = IInfo(proxy).unpaidPrincipal(tokenId);
        uint interest = IInfo(proxy).accruedInterest(tokenId);

        // Bidder redeems
        vm.startPrank(bidder);
        USDC.approve(proxy, 2 * (unpaidPrincipal + interest)); // Todo: improve later
        IBorrowing(proxy).redeemMortgage(tokenId);
        vm.stopPrank();
    }

    function _testForeclose(uint randomness) private {
        console.log("\ntestForelose...");

        // Make Actionable Loan Bid
        (, uint tokenId, uint idx) = _makeActionableLoanBid(randomness);

        // Seller accepts bid
        vm.prank(nftContract.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Skip time (to default)
        skip(30 days + 45 days);

        // PAC forecloses
        vm.prank(_PAC);
        IBorrowing(proxy).foreclose(tokenId);
    }

    function _testDeposit(uint randomness) private {
        console.log("\ntestDeposit...");
        _deposit(randomness);
    }

    function _testWithdraw(uint randomness) private {
        console.log("\ntestWithdraw...");

        // Get vars
        address withdrawer = _randomAddress(randomness);
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        uint usdc = bound(randomness, 0, availableLiquidity);
        console.log("usdc:", usdc);
        uint tUsdcBurn = IInfo(proxy).usdcToTUsdc(usdc);

        // Deal tUsdcBurn to withdrawer
        deal(address(tUSDC), withdrawer, tUsdcBurn);

        // Withdraw
        vm.prank(withdrawer);
        ILending(proxy).withdraw(usdc);
    }

    function _testSkip(uint randomness) private {
        console.log("\ntestSkip...");
        uint timeJump = bound(randomness, 0, 100 * 365 days); // Note: 0 to 100 years
        skip(timeJump);
    }


    // ----- UTILS -----
    function _randomTokenId(uint randomness) private returns(uint tokenId) {
        uint totalSupply = nftContract.totalSupply();
        tokenId = bound(randomness, 0, totalSupply - 1);
    }

    function _randomIdx(uint randomness, uint length) private returns(uint randomIdx) {
        randomIdx = bound(randomness, 0, length - 1);
    }

    function _randomAddress(uint randomness) private returns(address) {
        return vm.addr(bound(randomness, 1, 999_999_999));
    }

    function _randomResident(uint randomness) private returns(address) {
        uint randomResidentId = bound(randomness, 1, residentCount);
        return IInfo(proxy).residentToAddress(randomResidentId);
    }

    function _mintNfts(uint amount) private {
        console.log("\nmintNfts...");
        vm.startPrank(_GSP); // Note: only GSP can mint nfts
        for (uint i = 1; i <= amount; i++) {
            IResidents(proxy).verifyResident(vm.addr(i), i);
            nftContract.mint(vm.addr(i), "");
        }
        vm.stopPrank();
        residentCount = amount;
    }

    function _deposit(uint randomness) private {

        // Get buyer
        address buyer = _randomAddress(randomness);
        uint amount = bound(randomness, 10e6, 1_000_000_000e6); // Note: USDC has 6 decimals

        // Deal
        deal(address(USDC), buyer, amount);

        // Approve
        vm.prank(buyer);
        USDC.approve(proxy, amount);

        // Deposit
        vm.prank(buyer);
        ILending(proxy).deposit(amount);
    }

    function _makeActionableBid(uint randomness) private returns(address bidder, uint randomTokenId, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        randomTokenId = _randomTokenId(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint minPropertyValue = IInfo(proxy).unpaidPrincipal(randomTokenId) > 0 ? IInfo(proxy).minSalePrice(randomTokenId) : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 1_000_000_000e6); // Note: minPropertyValue to minPropertyValue + 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, propertyValue); // Note: add 1 to minDownPayment for precision loss

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(USDC), depositor, neededLiquidity);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            USDC.approve(proxy, neededLiquidity);
            ILending(proxy).deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(USDC), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        USDC.approve(proxy, downPayment);
        IAuctions(proxy).bid(randomTokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Get newBidIdx
        newBidIdx = IInfo(proxy).bidsLength(randomTokenId) - 1;
    }

    function _makeActionableLoanBid(uint randomness) private returns(address bidder, uint randomTokenId, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        randomTokenId = _randomTokenId(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint minPropertyValue = IInfo(proxy).unpaidPrincipal(randomTokenId) > 0 ? IInfo(proxy).minSalePrice(randomTokenId) : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 1_000_000_000e6); // Note: minPropertyValue to minPropertyValue + 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, 9 * propertyValue / 10); // Note: 50% to 90% of propertyValue

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(USDC), depositor, neededLiquidity);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            USDC.approve(proxy, neededLiquidity);
            ILending(proxy).deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(USDC), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        USDC.approve(proxy, downPayment);
        IAuctions(proxy).bid(randomTokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Get newBidIdx
        newBidIdx = IInfo(proxy).bidsLength(randomTokenId) - 1;
    }
}