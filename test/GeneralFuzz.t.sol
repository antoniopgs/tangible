// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "./TestUtils.sol";

// Protocol Contracts
import "../contracts/protocol/borrowing/IBorrowing.sol";
import "../contracts/protocol/interest/InterestConstant.sol";
import "../contracts/protocol/lending/ILending.sol";
import { Status } from "../contracts/types/Types.sol";

// Other
// import { convert } from "@prb/math/src/UD60x18.sol";
import { console } from "forge-std/console.sol";

contract GeneralFuzz is TestUtils {

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

        // Get tokenId
        uint tokenId = _randomTokenId(randomness);

        // Make Actionable Loan Bid
        (address bidder, uint idx) = _makeActionableLoanBid(tokenId, randomness);

        // Seller accepts bid
        vm.prank(nftContract.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Get & Skip by timeJump
        uint timeJump = bound(randomness, 0, 15 days);
        skip(timeJump);

        // Get payment
        uint payment = bound(randomness, 0, 1_000_000_000e6);

        // Bidder pays loan
        vm.startPrank(bidder);
        USDC.approve(proxy, payment);
        IBorrowing(proxy).payMortgage(tokenId, payment);
        vm.stopPrank();
    }

    function _testRedeemLoan(uint randomness) private {
        console.log("\ntestRedeemLoan...");

        // Get tokenId
        uint tokenId = _randomTokenId(randomness);

        // Make Actionable Loan Bid
        (address bidder, uint idx) = _makeActionableLoanBid(tokenId, randomness);

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

        // Get tokenId
        uint tokenId = _randomTokenId(randomness);

        // Make Actionable Loan Bid
        (, uint idx) = _makeActionableLoanBid(tokenId, randomness);

        // Seller accepts bid
        vm.prank(nftContract.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Skip time (to default)
        skip(30 days + 45 days + 15 days);

        // Make Actionable Loan Bid
        _makeActionableLoanBid(tokenId, randomness);

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
}