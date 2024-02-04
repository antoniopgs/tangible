// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Inheritance
import "./Utils.t.sol";

// Other
import { IState } from "../interfaces/state/IState.sol";

contract Handler is Utils {

    function bid(uint randomness) external {
        _makeActionableBid(randomness);
    }

    function cancelBid(uint randomness) external {

        // Bid
        (address bidder, uint tokenId, uint idx) = _makeActionableBid(randomness);

        // Bidder cancels bid
        vm.prank(bidder);
        IAuctions(proxy).cancelBid(tokenId, idx);
    }

    function acceptBid(uint randomness) external {

        // Bid
        (, uint tokenId, uint idx) = _makeActionableBid(randomness); // Todo: ensure bid is actionable later

        // Get seller
        address seller = PROPERTY.ownerOf(tokenId);

        // Seller accepts bid
        vm.prank(seller);
        IAuctions(proxy).acceptBid(tokenId, idx);
    }

    function payMortgage(uint randomness) external {

        // Get tokenId
        uint tokenId = _randomTokenId(randomness);

        // Make Actionable Loan Bid
        (address bidder, uint idx) = _makeActionableLoanBid(tokenId, randomness);

        // Seller accepts bid
        vm.prank(PROPERTY.ownerOf(tokenId));
        IAuctions(proxy).acceptBid(tokenId, idx);

        // Get & Skip by timeJump
        uint timeJump = bound(randomness, 0, 15 days);
        assert(IInfo(proxy).status(tokenId) == IState.Status.Mortgage);
        skip(timeJump);
        assert(IInfo(proxy).status(tokenId) == IState.Status.Mortgage);

        // Get payment
        uint payment = bound(randomness, 0, 1_000_000_000e6);

        // Give bidder UNDERLYING for payment
        deal(address(UNDERLYING), bidder, payment);

        // Bidder pays loan
        vm.startPrank(bidder);
        UNDERLYING.approve(address(vault), payment);
        IBorrowing(proxy).payMortgage(tokenId, payment);
        vm.stopPrank();
    }

    function foreclose(uint randomness) external {

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

    function deposit(uint randomness) external {
        _deposit(randomness);
    }

    function withdraw(uint randomness) external {

        // Get vars
        address withdrawer = _randomAddress(randomness);
        uint availableLiquidity = vault.availableLiquidity();
        uint underlying = bound(randomness, 0, availableLiquidity);

        // Update expectations
        expectedVaultDeposits -= underlying;

        // Calculate sharesBurn
        uint sharesBurn = vault.underlyingToShares(underlying);

        // Deal vault to withdrawer
        deal(address(vault), withdrawer, sharesBurn);

        // Withdraw
        vm.prank(withdrawer);
        vault.withdraw(underlying);

        // Update actualVaultDeposits
        actualVaultDeposits = vault.deposits();
    }

    function skipTime(uint randomness) external {
        uint timeJump = bound(randomness, 0, 100 * 365 days); // Note: 0 to 100 years
        skip(timeJump);
    }

    modifier validate {

        // Run
        _;

        // Get actuals
        actualVaultUtilization = vault.utilization();
    }
}