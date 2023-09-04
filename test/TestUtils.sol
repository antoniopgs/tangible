// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../script/Deploy.s.sol";
import { Test } from "lib/forge-std/src/Test.sol";

contract TestUtils is DeployScript, Test {

    uint residentCount;

    function _randomTokenId(uint randomness) internal returns(uint tokenId) {
        uint totalSupply = nftContract.totalSupply();
        tokenId = bound(randomness, 0, totalSupply - 1);
    }

    function _randomIdx(uint randomness, uint length) private returns(uint randomIdx) {
        randomIdx = bound(randomness, 0, length - 1);
    }

    function _randomAddress(uint randomness) internal returns(address) {
        return vm.addr(bound(randomness, 1, 999_999_999));
    }

    function _randomResident(uint randomness) private returns(address) {
        uint randomResidentId = bound(randomness, 1, residentCount);
        return IInfo(proxy).residentToAddress(randomResidentId);
    }

    function _mintNfts(uint amount) internal {
        console.log("\nmintNfts...");
        vm.startPrank(_GSP); // Note: only GSP can mint nfts
        for (uint i = 1; i <= amount; i++) {
            IResidents(proxy).verifyResident(vm.addr(i), i);
            nftContract.mint(vm.addr(i), "");
        }
        vm.stopPrank();
        residentCount = amount;
    }

    function _deposit(uint randomness) internal {

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

    function _makeActionableBid(uint randomness) internal returns(address bidder, uint randomTokenId, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        randomTokenId = _randomTokenId(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint minPropertyValue = IInfo(proxy).unpaidPrincipal(randomTokenId) > 0 ? IInfo(proxy).minSalePrice(randomTokenId) : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 1_000_000_000e6); // Note: minPropertyValue to minPropertyValue + 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, propertyValue); // Note: add 1 to minDownPayment for precision loss

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(USDC), depositor, neededLiquidity);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            USDC.approve(proxy, neededLiquidity);
            ILending(proxy).deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(USDC), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        USDC.approve(proxy, downPayment);
        IAuctions(proxy).bid(randomTokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Get newBidIdx
        newBidIdx = IInfo(proxy).bidsLength(randomTokenId) - 1;
    }

    function _makeActionableLoanBid(uint tokenId, uint randomness) internal returns(address bidder, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint minPropertyValue = IInfo(proxy).unpaidPrincipal(tokenId) > 0 ? IInfo(proxy).minSalePrice(tokenId) : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 1_000_000_000e6); // Note: minPropertyValue to minPropertyValue + 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, 9 * propertyValue / 10); // Note: 50% to 90% of propertyValue

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = IInfo(proxy).availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(USDC), depositor, neededLiquidity);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            USDC.approve(proxy, neededLiquidity);
            ILending(proxy).deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(USDC), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        USDC.approve(proxy, downPayment);
        IAuctions(proxy).bid(tokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Get newBidIdx
        newBidIdx = IInfo(proxy).bidsLength(tokenId) - 1;
    }
}