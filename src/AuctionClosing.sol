// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type Time is uint;

contract AuctionClosing {

    // Time public optionPeriodDuration = Time.wrap(10 days);
    uint optionPeriodDuration = 10 days;
    // Time public closingPeriodDuration = Time.wrap(30 days);
    uint closingPeriodDuration = 30 days;

    // Time public auctionOptionPeriodStart;
    uint public auctionOptionPeriodStart;

    function backout() external view {

        if (block.timestamp < auctionOptionPeriodStart) {
            revert("can't back out before option period starts");

        } else if (block.timestamp >= auctionOptionPeriodStart && block.timestamp < auctionOptionPeriodStart + optionPeriodDuration) {
            // we're in option period
            // user backing out pays option fee

        } else if (block.timestamp >= auctionOptionPeriodStart + optionPeriodDuration && block.timestamp < auctionOptionPeriodStart + optionPeriodDuration + closingPeriodDuration) {
            // we're in closing period    
            // user pays 1% penalty

        } else if (block.timestamp >= auctionOptionPeriodStart + optionPeriodDuration + closingPeriodDuration) {
            // closing period is over, transaction should have already been confirmed
            // confirm transaction
        }
    }
}