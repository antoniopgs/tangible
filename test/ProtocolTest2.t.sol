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

    uint eResidentCount;

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
        _deposit(randomness);
    }

    function _testWithdraw(uint randomness) private {
        address withdrawer = vm.addr(bound(randomness, 1, 999_999_999));
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
        _startNewLoan(randomness);
    }

    function _testPayLoan(uint randomness) private {

        console.log(0);

        // Get random loan tokenId
        uint tokenId = _randomLoanTokenId(randomness);

        // Get payment
        uint payment = bound(randomness, 1, 1_000_000_000e6); // Note: USDC has 6 decimals

        console.log(1);

        // Deal & Approve
        address payee = vm.addr(bound(randomness, 1, 999_999_999));
        deal(address(USDC), payee, payment);
        vm.prank(payee);
        USDC.approve(protocol, payment);

        console.log(2);

        // Pay loan
        vm.prank(payee);
        IBorrowing(protocol).payLoan(tokenId, payment);

        console.log(3);
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

        // Get loansTokenIdsLength
        uint loansTokenIdsLength = IInfo(protocol).loansTokenIdsLength();

        // If loans exist
        if (loansTokenIdsLength > 0) {

            // Return random loanTokenId
            uint randomIdx = bound(randomness, 0, loansTokenIdsLength);
            loanTokenId = IInfo(protocol).loansTokenIdsAt(randomIdx);

        // If no loans
        } else {

            // Start new loan & return tokenId
            loanTokenId = _startNewLoan(randomness);
        }
    }

    function _mintNfts(uint amount) private {
        for (uint i = 1; i <= amount; i++) {
            nftContract.verifyEResident(i, vm.addr(i));
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
        USDC.approve(protocol, amount);

        // Deposit
        vm.prank(buyer);
        ILending(protocol).deposit(amount);
    }

    function _startNewLoan(uint randomness) private returns(uint tokenId) {

        address buyer = randomEResident(randomness);
        tokenId = _randomTokenId(randomness);
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

    function randomEResident(uint randomness) private returns(address) {
        uint randomEResidentId = bound(randomness, 1, eResidentCount);
        return nftContract.eResidentToAddress(randomEResidentId);
    }
}