// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";

// Protocol Contracts
import "../contracts/protocol/borrowing/IBorrowing.sol";
import "../contracts/protocol/borrowingMath/BorrowingMath.sol";
import "../contracts/protocol/lending/ILending.sol";
import { Status } from "../contracts/types/Types.sol";

// Other
// import { convert } from "@prb/math/src/UD60x18.sol";
// import { console } from "forge-std/console.sol";

contract GeneralFuzz is Test, DeployScript {

    // Actions
    enum Action {
        Bid, LoanBid, CancelBid, // Buyers
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

            } else if (action == uint(Action.LoanBid)) {
                _testLoanBid(randomness[i]);

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

        address resident = _randomResident(randomness);
        uint randomTokenId = _randomTokenId(randomness);
        uint propertyValue = bound(randomness, 10e6, 1_000_000_000e6); // Note: 0 to 1 billion
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Resident bids
        vm.startPrank(resident);
        USDC.approve(proxy, propertyValue);
        deal(address(USDC), resident, propertyValue);
        IAuctions(proxy).bid(randomTokenId, propertyValue, loanMonths);
        vm.stopPrank();
    }

    function _testLoanBid(uint randomness) private {
        console.log("\ntestLoanBid...");

        address resident = _randomResident(randomness);
        uint randomTokenId = _randomTokenId(randomness);
        uint propertyValue = bound(randomness, 10e6, 1_000_000_000e6); // Note: 0 to 1 billion
        uint downPayment = bound(randomness, propertyValue / 2, propertyValue); // Note: maxLtv = 50%
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Resident loanBids
        vm.startPrank(resident);
        USDC.approve(proxy, downPayment);
        deal(address(USDC), resident, downPayment);
        IAuctions(proxy).loanBid(randomTokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();
    }

    function _testCancelBid(uint randomness) private {
        console.log("\ntestCancelBid...");

        // Get randomTokenId
        uint randomTokenId = _randomTokenId(randomness);

        // If nft has bids
        uint bidsLength = IInfo(proxy).bidsLength(randomTokenId);
        if (bidsLength > 0) {

            // Get randomIdx
            uint randomIdx = _randomIdx(randomness, bidsLength);

            // Bidder cancels bid
            vm.prank(IInfo(proxy).bids(randomTokenId, randomIdx).bidder);
            IAuctions(proxy).cancelBid(randomTokenId, randomIdx);
        }
    }

    function _testAcceptBid(uint randomness) private {
        console.log("\ntestAcceptBid...");

        // Get randomTokenId
        uint randomTokenId = _randomTokenId(randomness);
        
        // If nft has bids
        uint bidsLength = IInfo(proxy).bidsLength(randomTokenId);
        if (bidsLength > 0) {

            // Get randomIdx
            uint randomIdx = _randomIdx(randomness, bidsLength);

            // If bid is actionable
            if (IInfo(proxy).bidActionable(randomTokenId, randomIdx)) {

                // Nft owner accepts bid
                vm.prank(nftContract.ownerOf(randomTokenId));
                IAuctions(proxy).acceptBid(randomTokenId, randomIdx);
            }
        }
    }

    function _testPayLoan(uint randomness) private {
        console.log("\ntestPayLoan...");

        // Get random tokenId
        uint tokenId = _randomTokenId(randomness);

        // If Mortgage
        if (BorrowingMath(proxy).status(tokenId) == Status.Mortgage) {

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
        if (BorrowingMath(proxy).status(tokenId) == Status.Default && BorrowingMath(proxy).redeemable(tokenId)) {
            
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
        address withdrawer = _randomAddress(randomness);
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        uint usdc = bound(randomness, 0, availableLiquidity);
        uint tUsdcBurn = IInfo(proxy).usdcToTUsdc(usdc);

        // Deal tUSDC
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
}