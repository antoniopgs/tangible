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
// import { console } from "forge-std/console.sol";

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

        // Get random tokenId
        uint tokenId = _randomTokenId(randomness);

        // If Default && Redeemable
        if (LoanStatus(proxy).status(tokenId) == Status.Default && LoanStatus(proxy).redeemable(tokenId)) {
            
            // Redeem
            IBorrowing(proxy).redeemMortgage(tokenId); // Note: test this is getting reach with assert(false)
        }
    }

    function _testForeclose(uint randomness) private {
        console.log("\ntestForelose...");

        // Get randomTokenId
        uint randomTokenId = _randomTokenId(randomness);
        
        // If nft has bids
        uint bidsLength = IInfo(proxy).bidsLength(randomTokenId);
        if (bidsLength > 0) {

            // Get randomIdx
            uint randomIdx = _randomIdx(randomness, bidsLength);

            // If bid is actionable
            if (IInfo(proxy).bidActionable(randomTokenId, randomIdx)) {

                // PAC forecloses
                vm.prank(_PAC);
                IBorrowing(proxy).foreclose(randomTokenId, randomIdx);
            }
        }
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

        // Todo: Ensure availableLiquidity actionability?

        // Pick actionable propertyValue/salePrice
        uint minPropertyValue = IInfo(proxy).unpaidPrincipal(randomTokenId) > 0 ? IInfo(proxy).minSalePrice(randomTokenId) : 1;
        uint propertyValue = bound(randomness, minPropertyValue, 1_000_000_000e6); // Note: minSalePrice to 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, propertyValue); // Note: add 1 to minDownPayment for precision loss

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