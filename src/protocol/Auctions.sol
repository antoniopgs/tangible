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

    function bid(uint tokenId, UD60x18 bidAmount) external { // called by borrower // should we block seller from calling this?

        // Pull bid from caller/bidder to protocol
        USDC.safeTransferFrom(msg.sender, address(this), newBid);

        // Add Bidder to auction bidders
        auctions[tokenId].bidders.push(
            Bid({
                bidder: msg.sender,
                amount: bidAmount,
                loan: false
            })
        );
    }

    function loanBid(uint tokenId, UD60x18 bidAmount, UD60x18 downPayment) external { // called by borrower // should we block seller from calling this?

        // Calculate bid ltv
        UD60x18 ltv = toUD60x18(1).sub(downPayment.div(bidAmount));

        // Ensure bid ltv <= maxLtv
        require(ltv.lte(maxLtvPct), "ltv cannot exceed maxLtv");

        // Pull downPayment from caller/borrower to protocol
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add Bidder to auction bidders
        auctions[tokenId].bidders.push(
            Bid({
                bidder: msg.sender,
                amount: bidAmount,
                loan: true
            })
        );
    }

    function pullBid(uint tokenId) external {
        // require(, "only bidder can pull his bid");
    }

    function acceptLoanBid(uint tokenId, uint bidIdx) external { // called by seller

        // Get auction
        Auction memory auction = auctions[tokenId];

        // Ensure caller is seller
        require(msg.sender == auction.seller, "only seller can accept bids");

        // Get bid
        Bid memory _bid = auction.bids[bidIdx];

        // Send bid.amount from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, _bid.amount); // DON'T FORGET TO CHARGE FEE LATER

        // Send NFT from protocol to bidder
        prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);

        // Start optionPeriod
        auction.optionPeriodEnd = block.timestamp + optionPeriodDuration;
    }

    function loanBidActionable() public view returns(bool) {
        availableLiquidity >= principal
    }

    function acceptBid(uint tokenId, uint bidIdx) external {

        // Get auction
        Auction memory auction = auctions[tokenId];

        // Ensure caller is seller
        require(msg.sender == auction.seller, "only seller can accept bids");

        // Get bid
        Bid memory _bid = auction.bids[bidIdx];

        // Send bid.amount from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, _bid.amount); // DON'T FORGET TO CHARGE FEE LATER

        // Send NFT from protocol to bidder
        prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);

        // Start optionPeriod
        auction.optionPeriodEnd = block.timestamp + optionPeriodDuration;
    }
}