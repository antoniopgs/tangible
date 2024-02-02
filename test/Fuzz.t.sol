// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "./Utils.t.sol";

// Protocol Contracts
import "../interfaces/logic/IBorrowing.sol";
// import "../interfaces/logic/ILending.sol";
import "../contracts/protocol/logic/interest/InterestConstant.sol";
import "../interfaces/state/IState.sol";

// Other
import { console } from "forge-std/console.sol";

contract GeneralFuzz is Utils, IState { // Todo: figure out how to remove IState inheritance later

    // Actions
    enum Action {
        Bid, CancelBid, // Buyers
        AcceptBid, // Sellers
        PayMortgage, // Borrower
        Foreclose, // PAC
        Deposit, Withdraw, // Lenders,
        SkipTime // Util
    }
    
    // Expectation Varsx
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;

    // Main
    function test(uint[100] calldata randomness) public {

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
                
            } else if (action == uint(Action.Foreclose)) {
                // _testForeclose(randomness[i]);
            
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
        address seller = PROPERTY.ownerOf(tokenId);

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
        vm.prank(PROPERTY.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Get & Skip by timeJump
        uint timeJump = bound(randomness, 0, 15 days);
        assert(IInfo(proxy).status(tokenId) == Status.Mortgage);
        skip(timeJump);
        assert(IInfo(proxy).status(tokenId) == Status.Mortgage);

        // Get payment
        uint payment = bound(randomness, 0, 1_000_000_000e6);

        // Give bidder UNDERLYING for payment
        deal(address(UNDERLYING), bidder, payment);

        // Bidder pays loan
        vm.startPrank(bidder);
        UNDERLYING.approve(proxy, payment);
        IBorrowing(proxy).payMortgage(tokenId, payment);
        vm.stopPrank();
    }

    function _testForeclose(uint randomness) private {
        console.log("\ntestForelose...");

        // Get tokenId
        uint tokenId = _randomTokenId(randomness);

        // Make Actionable Loan Bid
        (, uint idx) = _makeActionableLoanBid(tokenId, randomness);

        // Seller accepts bid
        vm.prank(PROPERTY.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Skip time (to default)
        skip(30 days + 45 days + 15 days);

        // Make Actionable Loan Bid
        _makeActionableLoanBid(tokenId, randomness);

        // Admin forecloses
        vm.prank(Ownable(proxy).owner());
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
        uint underlying = bound(randomness, 0, availableLiquidity);
        console.log("underlying:", underlying);
        uint sharesBurn = ILending(proxy).underlyingToShares(underlying);

        // Deal sharesBurn to withdrawer
        deal(address(SHARES), withdrawer, sharesBurn);

        // Withdraw
        vm.prank(withdrawer);
        ILending(proxy).withdraw(underlying);
    }

    function _testSkip(uint randomness) private {
        console.log("\ntestSkip...");
        uint timeJump = bound(randomness, 0, 100 * 365 days); // Note: 0 to 100 years
        skip(timeJump);
    }
}