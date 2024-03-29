// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../script/Deploy.s.sol";
import { Test } from "lib/chainlink/contracts/foundry-lib/forge-std/src/Test.sol"; // Todo: fix foundry imports later

contract Utils is DeployScript, Test {

    uint residentCount;

    function _randomTokenId(uint randomness) internal view returns(uint tokenId) {
        uint totalSupply = PROPERTY.totalSupply();
        tokenId = bound(randomness, 0, totalSupply - 1);
    }

    function _randomAddress(uint randomness) internal view returns(address) {
        return vm.addr(bound(randomness, 1, 999_999_999));
    }

    function _randomResident(uint randomness) private view returns(address) {
        uint randomResidentId = bound(randomness, 1, residentCount);
        return IInfo(proxy).residentToAddress(randomResidentId);
    }

    function mintNfts(uint amount) public {
        vm.startPrank(PROPERTY.owner());
        for (uint i = 1; i <= amount; i++) {
            IResidents(proxy).verifyResident(vm.addr(i), i);
            PROPERTY.mint(vm.addr(i), "");
        }
        vm.stopPrank();
        residentCount = amount; // Todo: maybe change this later (doesn't need to be one nft per resident)
    }

    function _deposit(uint randomness) internal {

        // Get depositor
        address depositor = _randomAddress(randomness);
        uint amount = bound(randomness, 10e6, 1_000_000_000e6); // Note: UNDERLYING has 6 decimals

        // Deal
        deal(address(UNDERLYING), depositor, amount);

        // Approve
        vm.prank(depositor);
        UNDERLYING.approve(address(pool), amount);

        // Admin registers depositor as eligible
        vm.prank(pool.owner());
        pool.updateUserEligible(depositor, true);

        // Deposit
        vm.prank(depositor);
        pool.deposit(amount);
    }

    function _makeActionableBid(uint randomness) internal returns(address bidder, uint randomTokenId, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        randomTokenId = _randomTokenId(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint sellerDebt = IInfo(proxy).unpaidPrincipal(randomTokenId) +  IInfo(proxy).accruedInterest(randomTokenId);
        uint minPropertyValue = sellerDebt > 0 ? sellerDebt : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 1_000_000_000e6); // Note: minPropertyValue to minPropertyValue + 1 billion

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, propertyValue); // Note: add 1 to minDownPayment for precision loss

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = pool.availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(UNDERLYING), depositor, neededLiquidity);

            // Admin registers depositor as eligible
            vm.prank(pool.owner());
            pool.updateUserEligible(depositor, true);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            UNDERLYING.approve(address(pool), neededLiquidity);
            pool.deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(UNDERLYING), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        UNDERLYING.approve(proxy, downPayment);
        newBidIdx = IAuctions(proxy).bid(randomTokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Ensure new bid is actionable
        assert(IInfo(proxy).bidActionable(randomTokenId, newBidIdx));
    }

    function _makeActionableLoanBid(uint tokenId, uint randomness) internal returns(address bidder, uint newBidIdx) {
        
        // Get vars
        bidder = _randomResident(randomness);
        uint loanMonths = bound(randomness, 6, 120); // Note: 6 months to 10 years

        // Pick actionable propertyValue/salePrice
        uint sellerDebt = IInfo(proxy).unpaidPrincipal(tokenId) +  IInfo(proxy).accruedInterest(tokenId);
        uint minPropertyValue = sellerDebt > 0 ? sellerDebt : 1;
        uint propertyValue = bound(randomness, minPropertyValue, minPropertyValue + 100_000_000e6); // Note: minPropertyValue to minPropertyValue + 100 millon // Note: UNDERLYING has 6 Decimals

        // Pick actionable downPayment
        UD60x18 maxLtv = IInfo(proxy).maxLtv();
        uint downPayment = bound(randomness, convert(maxLtv.mul(convert(propertyValue))) + 1, 9 * propertyValue / 10); // Note: 50% to 90% of propertyValue
        
        assert(propertyValue - downPayment > 0);

        // Ensure there's enough availableLiquidity
        uint availableLiquidity = pool.availableLiquidity();
        if (availableLiquidity < downPayment) {

            // Get depositor
            address depositor = makeAddr("depositor");

            // Give neededLiquidity to depositor
            uint neededLiquidity = downPayment - availableLiquidity;
            deal(address(UNDERLYING), depositor, neededLiquidity);

            // Admin registers depositor as eligible
            vm.prank(pool.owner());
            pool.updateUserEligible(depositor, true);

            // Depositor approves & deposits
            vm.startPrank(depositor);
            UNDERLYING.approve(address(pool), neededLiquidity);
            pool.deposit(neededLiquidity);
            vm.stopPrank();
        }

        // Deal downPayment to bidder
        deal(address(UNDERLYING), bidder, downPayment);

        // Bidder approves & bids
        vm.startPrank(bidder);
        UNDERLYING.approve(proxy, downPayment);
        newBidIdx = IAuctions(proxy).bid(tokenId, propertyValue, downPayment, loanMonths);
        vm.stopPrank();

        // Ensure new bid is actionable
        assert(IInfo(proxy).bidActionable(tokenId, newBidIdx));
    }
}