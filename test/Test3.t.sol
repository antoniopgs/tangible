// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Main
import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "forge-std/console.sol";

contract Test3 is Test, DeployScript {

    function test() external {
        
        // Depositor deposits 25k
        address depositor = makeAddr("depositor");
        deal(address(USDC), depositor, 25_000e18);
        vm.prank(depositor);
        USDC.approve(address(protocol), 25_000e18);
        vm.prank(depositor);
        ILending(protocol).deposit(25_000e18);

        // Mint nft to nftOwner
        address nftOwner = makeAddr("nftOwner");
        nftContract.verifyEResident(1, nftOwner);
        nftContract.mint(nftOwner, "");

        console.log("status a:", uint(Status(protocol).status(0)));
        console.log("");

        // Bidder bids
        address bidder = makeAddr("bidder");
        nftContract.verifyEResident(2, bidder);
        deal(address(USDC), bidder, 75_000e18);
        vm.prank(bidder);
        USDC.approve(address(protocol), 75_000e18);
        vm.prank(bidder);
        IAuctions(protocol).bid({
            tokenId: 0,
            propertyValue: 100_000e18,
            downPayment: 75_000e18,
            maxDurationMonths: 120
        });

        console.log("status b:", uint(Status(protocol).status(0)));
        console.log("");

        // nftOwner accepts bid
        vm.prank(nftOwner);
        nftContract.approve(address(protocol), 0);
        vm.prank(nftOwner);
        IAuctions(protocol).acceptBid({
            tokenId: 0,
            bidIdx: 0
        });

        console.log("status c:", uint(Status(protocol).status(0)));
        console.log("");

        uint monthSeconds = 365 days / 12;
        skip(monthSeconds);

        console.log("status d:", uint(Status(protocol).status(0)));
        console.log("");

        skip(monthSeconds / 2);

        console.log("status e:", uint(Status(protocol).status(0)));
        console.log("");

        skip(monthSeconds);

        console.log("status f:", uint(Status(protocol).status(0)));
        console.log("");
    }
}