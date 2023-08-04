// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";

// Protocol Contracts
import "../contracts/protocol/borrowing/borrowing/IBorrowing.sol";
import "../contracts/protocol/lending/ILending.sol";
import "../contracts/protocol/state/state/IState.sol";

// Other
import "forge-std/console.sol";

contract ProtocolTest2 is Test, DeployScript {

    // Actions
    enum Action {
        Deposit, Withdraw, // Lenders
        StartNewLoan, // Admin
        PayLoan, RedeemLoan, // Buyer
        SkipTime // Util
    }
    
    // Expectation Vars
    uint expectedTotalPrincipal;
    uint expectedTotalDeposits;
    // uint expectedMaxTotalInterestOwed;

    // Main
    function testMath(uint[] calldata randomness) public {

        _mintNfts(100);

        // Loop actions
        for (uint i = 0; i < randomness.length; i++) {

            // Get action
            uint action = randomness[i] % (uint(type(Action).max) + 1);

            // If Start
            if (action == uint(Action.Deposit)) {
                console.log("\nAction.Deposit");
                _testDeposit(randomness[i]);

            } else if (action == uint(Action.Withdraw)) {
                console.log("\nAction.Withdraw");
                _testWithdraw(randomness[i]);
                
            } else if (action == uint(Action.StartNewLoan)) {
                console.log("\nAction.StartNewLoan");
                _testStartNewLoan(randomness[i]);
            
            } else if (action == uint(Action.PayLoan)) {
                console.log("\nAction.PayLoan");
                _testPayLoan(randomness[i]);

            } else if (action == uint(Action.RedeemLoan)) {
                console.log("\nAction.RedeemLoan");
                _testRedeemLoan(randomness[i]);

            } else if (action == uint(Action.SkipTime)) {
                console.log("\nAction.SkipTime");
                _testSkip(randomness[i]);
            }
        }
    }

    function _testDeposit(uint randomness) private {
        uint usdc = bound(randomness, 0, 1_000_000_000e6); // Note: USDC has 6 decimals
        _deposit(usdc);
    }

    function _testWithdraw(uint randomness) private {
        address withdrawer = makeAddr("withdrawer");
        uint availableLiquidity = IInfo(protocol).availableLiquidity();
        uint usdc = bound(randomness, 0, availableLiquidity);
        uint tUsdcBurn = IInfo(protocol).usdcToTUsdc(usdc);

        // Deal tUSDC
        deal(address(tUSDC), withdrawer, tUsdcBurn);

        // Withdraw
        vm.prank(withdrawer);
        ILending(protocol).withdraw(usdc);
    }

    function _testStartNewLoan(uint randomness) private {
        
        address buyer = vm.addr(bound(randomness, 1, 999_999_999));
        uint tokenId = _randomTokenId(randomness);
        uint propertyValue = bound(randomness, 10_000e6, 1_000_000_000e6); // Note: USDC has 6 decimals
        uint downPayment = bound(randomness, propertyValue / 2, propertyValue); // Note: maxLtv is 50%
        uint maxDurationMonths = bound(randomness, 1, 100 * 12); // Note: 1 to 100 years

        // If nft is ResidentOwned
        if (IInfo(protocol).status(tokenId) == IStatus.Status.ResidentOwned) {

            // nftOwner approves protocol
            address nftOwner = nftContract.ownerOf(tokenId);
            vm.prank(nftOwner);
            nftContract.approve(protocol, tokenId);
        }

        // Give buyer downPayment & approve
        deal(address(USDC), buyer, downPayment);
        vm.prank(buyer);
        USDC.approve(protocol, downPayment);

        // Deposit principal
        _deposit(propertyValue - downPayment);
        
        // Start New Loan
        IBorrowing(protocol).startNewLoan(
            buyer,
            tokenId,
            propertyValue,
            downPayment,
            maxDurationMonths
        );
    }

    function _testPayLoan(uint randomness) private {
        uint tokenId = _randomLoanTokenId(randomness);
        uint payment = bound(randomness, 1, 1_000_000_000e6); // Note: USDC has 6 decimals
        IBorrowing(protocol).payLoan(tokenId, payment);
    }

    function _testRedeemLoan(uint randomness) private {
        uint tokenId = _randomLoanTokenId(randomness);
        IBorrowing(protocol).redeemLoan(tokenId);
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

    function _randomLoanTokenId(uint randomness) private returns(uint loanTokenId) {
        uint loansTokenIdsLength = IInfo(protocol).loansTokenIdsLength();
        console.log("loansTokenIdsLength:", loansTokenIdsLength);
        uint randomIdx = bound(randomness, 0, loansTokenIdsLength);
        loanTokenId = IInfo(protocol).loansTokenIdsAt(randomIdx);
    }

    function _mintNfts(uint amount) private {
        for (uint i = 1; i <= amount; i++) {
            nftContract.verifyEResident(i, vm.addr(i));
            nftContract.mint(vm.addr(i), "");
        }
    }

    function _deposit(uint amount) private {

        // Get buyer
        address buyer = makeAddr("depositor");

        // Deal
        deal(address(USDC), buyer, amount);

        // Approve
        vm.prank(buyer);
        USDC.approve(protocol, amount);

        // Deposit
        vm.prank(buyer);
        ILending(protocol).deposit(amount);
    }
}