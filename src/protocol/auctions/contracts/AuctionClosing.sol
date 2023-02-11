// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IAuctions.sol";
import "../../mortgages/contracts/Lending.sol";

abstract contract AuctionClosing is IAuctions, Lending {

    uint public optionPeriodDuration = 10 days;
    uint public closingPeriodDuration = 30 days;
    UD60x18 public optionFee;
    UD60x18 public closingFee;

    mapping(uint => Auction) public auctions;

    using SafeERC20 for IERC20;

    function beforeOptionPeriod(Auction memory auction) private pure returns (bool) {
        return auction.optionPeriodEnd == 0;
    }

    function inOptionPeriod(Auction memory auction) private view returns (bool) {
        return block.timestamp < auction.optionPeriodEnd;
    }

    function inClosingPeriod(Auction memory auction) private view returns (bool) {
        return block.timestamp >= auction.optionPeriodEnd && block.timestamp < auction.optionPeriodEnd + closingPeriodDuration;
    }

    function afterClosingPeriod(Auction memory auction) private view returns (bool) {
        return block.timestamp >= auction.optionPeriodEnd + closingPeriodDuration;
    }

    function backout(uint tokenId) external {

        Auction memory auction = auctions[tokenId];

        if (beforeOptionPeriod(auction)) {
            revert("can't back out before option period starts");

        } else if (inOptionPeriod(auction)) {

            // user backing out pays option fee
            USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(optionFee));

        } else if (inClosingPeriod(auction)) {

            // user backing out pays closingFee
            USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(closingFee));

        } else if (afterClosingPeriod(auction)) {

            // If after closing period, loan should have already started. If it hasn't, start it.
            // if (loanNotStarted) {

                // Send highestBid/propertyValue from protocol to seller
                USDC.safeTransferFrom(msg.sender, auction.seller, auction.highestBidder.bid);

                // Start Loan
                startLoan({
                    tokenId: tokenId,
                    propertyValue: auction.highestBidder.bid,
                    borrower: auction.highestBidder.addr,
                    seller: auction.seller // replace with msg.sender?
                });

            // }
        }
    }
}