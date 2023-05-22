// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

contract Test2 is Test, DeployScript {

    function test() external {

        // Get nftOwner
        address nftOwner = makeAddr("nftOwner");

        // Verify nftOwner
        nftContract.verifyEResident(1, nftOwner);

        // Mint nft to nftOwner
        nftContract.mint(nftOwner, "");
        nftContract.mint(nftOwner, "");
        nftContract.mint(nftOwner, "");

        // Get bidder
        address bidder = makeAddr("bidder");

        // Verify bidder
        nftContract.verifyEResident(2, bidder);

        // Give bidder bid
        deal(address(USDC), bidder, 100_000e18);

        // Bidder approves protocol
        vm.prank(bidder);
        USDC.approve(address(protocol), 100_000e18);

        address depositor = makeAddr("depositor");
        deal(address(USDC), depositor, 25_000e18);
        vm.prank(depositor);
        USDC.approve(address(protocol), 25_000e18);
        vm.prank(depositor);
        ILending(protocol).deposit(25_000e18);

        // Bidder bids
        vm.prank(bidder);
        IAuctions(protocol).bid({
            tokenId: 2,
            propertyValue: 100_000e18,
            downPayment: 75_000e18,
            maxDurationMonths: 120
        });

        // nftOwner approves protocol
        vm.prank(nftOwner);
        nftContract.approve(address(protocol), 2);

        // nftOwner accepts bid
        vm.prank(nftOwner);
        IAuctions(protocol).acceptBid({
            tokenId: 2,
            bidIdx: 0
        });

        console.log("1");

        vm.prank(bidder);
        uint[] memory myLoansTokenIds = IInfo(protocol).myLoans();

        console.log("myLoansTokenIds.length", myLoansTokenIds.length);
        for (uint i = 0; i < myLoansTokenIds.length; i++) {
            console.log("myLoansTokenIds[i]:", myLoansTokenIds[i]);
        }
    }
}