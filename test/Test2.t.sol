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

        // Get bidder
        address bidder = makeAddr("bidder");

        // Verify bidder
        nftContract.verifyEResident(2, bidder);

        // Give bidder bid
        deal(address(USDC), bidder, 100_000e18);

        // Bidder approves protocol
        vm.prank(bidder);
        USDC.approve(address(protocol), 100_000e18);

        // Bidder bids
        vm.prank(bidder);
        IAuctions(protocol).bid({
            tokenId: 0,
            propertyValue: 100_000e18,
            downPayment: 100_000e18,
            maxDurationMonths: 120
        });

        // nftOwner approves protocol
        vm.prank(nftOwner);
        nftContract.approve(address(protocol), 0);

        // nftOwner accepts bid
        vm.prank(nftOwner);
        IAuctions(protocol).acceptBid({
            tokenId: 0,
            bidIdx: 0
        });
    }
}