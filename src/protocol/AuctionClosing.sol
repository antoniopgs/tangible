// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type Time is uint;

import "../interfaces/IAuctions.sol";
import "@prb/math/UD60x18.sol";

abstract contract AuctionClosing is IAuctions {

    uint public optionPeriodDuration = 10 days;
    uint public closingPeriodDuration = 30 days;

    function beforeOptionPeriod(Auction calldata auction) private pure returns (bool) {
        return auction.optionPeriodEnd == 0;
    }

    function inOptionPeriod(Auction calldata auction) private view returns (bool) {
        return block.timestamp < auction.optionPeriodEnd;
    }

    function inClosingPeriod(Auction calldata auction) private view returns (bool) {
        return block.timestamp >= auction.optionPeriodEnd && block.timestamp < auction.optionPeriodEnd + closingPeriodDuration;
    }

    function afterClosingPeriod(Auction calldata auction) private view returns (bool) {
        return block.timestamp >= auction.optionPeriodEnd + closingPeriodDuration;
    }

    function backout(Auction calldata auction) external view {

        if (beforeOptionPeriod(auction)) {
            revert("can't back out before option period starts");

        } else if (inOptionPeriod(auction)) {

            // user backing out pays option fee
            UD60x18 memory optionFee;

        } else if (inClosingPeriod(auction)) {

            // user backing out pays 1% penalty
            UD60x18 memory closingFee;

        } else if (afterClosingPeriod(auction)) {
            // transaction should have already been confirmed. confirm transaction

            // Start Loan
            startLoan();
        }
    }
}