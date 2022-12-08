// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Math.sol";

contract Auctions is Math, ERC721Holder {

    struct Bidder {
        address addr;
        uint bid;
    }

    struct Auction {
        address seller;
        uint buyoutPrice;
        Bidder highestBidder;
    }

    IERC721 prosperaNftContract;
    mapping(uint => Auction) public auctions;

    using SafeERC20 for IERC20;

    function startAuction(uint tokenId, uint buyoutPrice) external {

        // Pull NFT from seller
        prosperaNftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Store auction
        Auction storage auction = auctions[tokenId];
        auction.seller = msg.sender;
        auction.buyoutPrice = buyoutPrice;
    }

    function buyout(uint tokenId) external { // called by borrower // should we block seller from calling this?
        
        // Get auction
        Auction memory auction = auctions[tokenId];
        
        // Pull buyoutPrice from msg.sender/buyer to seller
        USDC.safeTransferFrom(msg.sender, auction.seller, auction.buyoutPrice);

        // Send NFT to msg.sender/buyer
        prosperaNftContract.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function loanBuyout(uint tokenId) external { // called by borrower // should we block seller from calling this?
        
        // Get auction
        Auction memory auction = auctions[tokenId];
        
        // Pull down payment from msg.sender/buyer to seller

        // Send principal from protocol to seller

        // Collateralize NFT

        // Start Loan
        // startLoan();
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

    function loanBid(uint tokenId, uint newBid) external { // called by borrower // should we block seller from calling this?

        // Get highestBidder
        Bidder storage highestBidder = auctions[tokenId].highestBidder;

        // Ensure newBid > highestBidder
        require(newBid > highestBidder.bid, "new bid must be greater than current highest bid");

        // Refund highestBidder
        USDC.safeTransfer(highestBidder.addr, highestBidder.bid);

        // Pull bid from caller/borrower to protocol
        USDC.safeTransferFrom(msg.sender, address(this), newBid);

        // Update highestBidder
        highestBidder.addr = msg.sender;
        highestBidder.bid = newBid;
    }

    function acceptBid(Auction calldata auction) external { // called by seller
        require(msg.sender == auction.seller, "only seller can accept bids");

        if (/* loanBid */) {
            _acceptLoanBid();

        } else {
            _acceptBid();
        }

        // Pull bid from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, auction.highestBidder.bid);

    }

    function _acceptBid(uint tokenId) private {

        // Get auction
        Auction memory auction = auctions[tokenId];

        // Pull bid from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, auction.highestBidder.bid);

        // Send NFT from protocol to bidder
        prosperaNftContract.safeTransferFrom(address(this), auction.higherBidder.addr, tokenId);
    }

    function _acceptLoanBid() private {

        // Send highest bid from protocol to seller

        // Send principal from protocol to seller

        // Collateralize NFT

        // Start Loan
        // startLoan();
    }

    function startLoan(address seller, uint salePrice, uint principal, address borrower) private {

        // Pull principal from protocol to seller
        USDC.safeTransferFrom(address(this), seller, principal);

        // Pull downPayment from borrower to seller
        uint downPayment = salePrice - principal;
        USDC.safeTransferFrom(borrower, seller, downPayment);
    }
}