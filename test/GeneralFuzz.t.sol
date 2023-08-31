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

contract GeneralFuzz is Test, DeployScript {

    // Actions
    enum Action {
        Bid, LoanBid, CancelBid, // Buyers
        AcceptBid, PayMortgage, RedeemMortgage, // Sellers
        Foreclose, // PAC
        Deposit, Withdraw, // Lenders,
        SkipTime // Util
    }
    
    // Expectation Vars
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;

    uint eResidentCount;

    // Main
    function testMath(uint[] calldata randomness) public {

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

        uint tokenId;
        uint propertyValue;
        uint loanMonths;

        IAuctions(proxy).bid(tokenId, propertyValue, loanMonths);
    }

    function _testLoanBid(uint randomness) private {

        uint tokenId;
        uint propertyValue;
        uint downPayment;
        uint loanMonths;

        IAuctions(proxy).loanBid(tokenId, propertyValue, downPayment, loanMonths);
    }

    function _testCancelBid(uint randomness) private {

        uint tokenId;
        uint idx;

        IAuctions(proxy).cancelBid(tokenId, idx);
    }

    function _testAcceptBid(uint randomness) private {

        uint tokenId;
        uint idx;

        IAuctions(proxy).acceptBid(tokenId, idx);
    }

    function _testPayLoan(uint randomness) private {

        // Get random tokenId
        uint tokenId = _randomTokenId(randomness);

        // If Mortgage
        if (BorrowingMath(proxy).status(tokenId) == Status.Mortgage) {

            // Get payment
            uint payment = bound(randomness, 1, 1_000_000_000e6); // Note: USDC has 6 decimals

            // Deal & Approve
            address payee = vm.addr(bound(randomness, 1, 999_999_999));
            deal(address(USDC), payee, payment);
            vm.prank(payee);
            USDC.approve(proxy, payment);

            // Pay loan
            vm.prank(payee);
            IBorrowing(proxy).payMortgage(tokenId, payment);
        }
    }

    function _testRedeemLoan(uint randomness) private {

        // Get random tokenId
        uint tokenId = _randomTokenId(randomness);

        // If Default
        if (BorrowingMath(proxy).status(tokenId) == Status.Default) {
            IBorrowing(proxy).redeemMortgage(tokenId); // Note: test this is getting reach with assert(false)
        }
    }

    function _testForeclose(uint randomness) private {

        uint tokenId;
        uint idx;

        IBorrowing(proxy).foreclose(tokenId, idx);
    }

    function _testDeposit(uint randomness) private {
        _deposit(randomness);
    }

    function _testWithdraw(uint randomness) private {
        address withdrawer = vm.addr(bound(randomness, 1, 999_999_999));
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
        uint timeJump = bound(randomness, 0, 100 * 365 days); // Note: 0 to 100 years
        skip(timeJump);
    }


    // ----- UTILS -----
    function _randomTokenId(uint randomness) private returns(uint tokenId) {
        uint totalSupply = nftContract.totalSupply();
        tokenId = bound(randomness, 0, totalSupply);
    }

    function _mintNfts(uint amount) private {
        for (uint i = 1; i <= amount; i++) {
            IResidents(proxy).verifyResident(vm.addr(i), i);
            nftContract.mint(vm.addr(i), "");
        }
        eResidentCount = amount;
    }

    function _deposit(uint randomness) private {

        // Get buyer
        address buyer = vm.addr(bound(randomness, 1, 999_999_999));
        uint amount = bound(randomness, 0, 1_000_000_000e6); // Note: USDC has 6 decimals

        // Deal
        deal(address(USDC), buyer, amount);

        // Approve
        vm.prank(buyer);
        USDC.approve(proxy, amount);

        // Deposit
        vm.prank(buyer);
        ILending(proxy).deposit(amount);
    }

    function randomEResident(uint randomness) private returns(address) {
        uint randomEResidentId = bound(randomness, 1, eResidentCount);
        return IInfo(proxy).residentToAddress(randomEResidentId);
    }
}