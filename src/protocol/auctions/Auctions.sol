// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/IBorrowing.sol";
import "../pool/IPool.sol";

contract Auctions is IAuctions, ERC721Holder {
    
    // Storage
    mapping(uint => Auction) public auctions;

    // Links
    IERC721 prosperaNftContract;
    IERC20 USDC;
    IBorrowing borrowing;
    IPool pool;

    using SafeERC20 for IERC20;

    function startAuction(uint tokenId) external {

        // Pull NFT from seller
        prosperaNftContract.safeTransferFrom(msg.sender, address(this), tokenId); // NFT COMES LATER

        // Store auction
        Auction storage auction = auctions[tokenId];
        auction.seller = msg.sender;
    }

    function bid(uint tokenId, uint propertyValue, uint downPayment) external {

        // Calculate bid ltv
        uint ltv = 1 - (downPayment / propertyValue);

        // Ensure bid ltv <= maxLtv
        require(ltv <= borrowing.maxLtv(), "ltv cannot exceed maxLtv");

        // Pull downPayment bidder to protocol
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add Bidder to auction bids
        auctions[tokenId].bids.push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment
            })
        );
    }

    function acceptBid(uint tokenId, uint bidIdx) external {

        // Get auction
        Auction memory auction = auctions[tokenId];

        // Ensure caller is seller
        require(msg.sender == auction.seller, "only seller can accept bids");

        // Get bid
        Bid memory _bid = auction.bids[bidIdx];

        // If regular bid
        if (_bid.downPayment == _bid.propertyValue) {

            // Send bid.propertyValue from protocol to seller
            USDC.safeTransferFrom(address(this), auction.seller, _bid.propertyValue); // DON'T FORGET TO CHARGE FEE LATER

            // Send NFT from protocol to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId); // NFT COMES LATER
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // Send bid.propertyValue from protocol to seller
            USDC.safeTransferFrom(address(this), auction.seller, _bid.propertyValue); // DON'T FORGET TO CHARGE FEE LATER

            // Start Loan
            borrowing.startLoan({
                tokenId: tokenId,
                propertyValue: _bid.propertyValue,
                principal: _bid.propertyValue - _bid.downPayment,
                borrower: _bid.bidder
            });
        }
    }

    function cancelBid(uint tokenId, uint bidIdx) external {

        // Get auctionBids
        Bid[] storage auctionBids = auctions[tokenId].bids;

        // Get bidToCancel
        Bid memory bidToCancel = auctionBids[bidIdx];

        // Ensure caller is bidder
        require(msg.sender == bidToCancel.bidder, "only bidder can cancel his bid");

        // Get lastBid
        Bid memory lastBid = auctionBids[auctionBids.length - 1];

        // Write lastBid over bidIdx
        auctionBids[bidIdx] = lastBid;

        // Remove lastBid
        auctionBids.pop();

        // Send bidToCancel.downPayment from protocol to bidder
        USDC.safeTransferFrom(address(this), bidToCancel.bidder, bidToCancel.downPayment);
    }

    function loanBidActionable(Bid memory _bid) public view returns(bool) {

        // Calculate loanBid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate loanBid ltv
        uint ltv = principal / _bid.propertyValue; // FIX LATER

        // Return actionability
        return ltv <= borrowing.maxLtv() && pool.availableLiquidity() >= principal;
    }
}