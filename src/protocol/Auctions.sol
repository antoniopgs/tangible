// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IAuctions.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AuctionClosing.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./Lending.sol";

abstract contract Auctions is IAuctions, AuctionClosing, ERC721Holder {

    using SafeERC20 for IERC20;

    function startAuction(uint tokenId) external {

        // Pull NFT from seller
        prosperaNftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Store auction
        Auction storage auction = auctions[tokenId];
        auction.seller = msg.sender;
    }

    function bid(uint tokenId, uint newBid) external { // called by borrower // should we block seller from calling this?

        // Get highestBidder
        Bidder storage highestBidder = auctions[tokenId].highestBidder;

        // Ensure newBid > highestBidder
        require(newBid > highestBidder.bid, "new bid must be greater than current highest bid");

        // Refund highestBidder
        USDC.safeTransfer(highestBidder.addr, highestBidder.bid);

        // Pull bid from caller/bidder to protocol
        USDC.safeTransferFrom(msg.sender, address(this), newBid);

        // Update highestBidder
        highestBidder.addr = msg.sender;
        highestBidder.bid = newBid;
    }

    function loanBid(uint tokenId, uint newBid, uint downPayment) external { // called by borrower // should we block seller from calling this?

        // Get highestBidder
        Bidder storage highestBidder = auctions[tokenId].highestBidder;

        // Ensure newBid > highestBidder
        require(newBid > highestBidder.bid, "new bid must be greater than current highest bid");

        // Refund highestBidder
        USDC.safeTransfer(highestBidder.addr, highestBidder.bid);

        // Pull downPayment from caller/borrower to protocol
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Update highestBidder
        highestBidder.addr = msg.sender;
        highestBidder.bid = newBid;
    }

    function acceptBid(uint tokenId) external { // called by seller

        // Get auction
        Auction memory auction = auctions[tokenId];

        require(msg.sender == auction.seller, "only seller can accept bids");

        if (/* loanBid */true) {
            _acceptLoanBid(tokenId, auction);

        } else {
            _acceptBid(tokenId, auction);
        }

        // Pull bid from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, auction.highestBidder.bid);

    }

    function _acceptBid(uint tokenId, Auction memory auction) private {

        // Send bid from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, auction.highestBidder.bid);

        // Send NFT from protocol to bidder
        prosperaNftContract.safeTransferFrom(address(this), auction.highestBidder.addr, tokenId);
    }

    function _acceptLoanBid(uint tokenId, Auction memory auction) private {
        auction.optionPeriodEnd = block.timestamp + optionPeriodDuration;
    }
}