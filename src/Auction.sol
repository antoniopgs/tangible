// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Auctions is ERC721Holder {

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
    IERC20 DAI;
    mapping(uint => Auction) public auctions;

    using SafeERC20 for IERC20;

    function auction(uint tokenId, uint buyoutPrice) external {

        // Pull NFT from seller
        prosperaNftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Store auction
        Auction storage auction = auctions[tokenId];
        auction.seller = msg.sender;
        auction.buyoutPrice = buyoutPrice;
    }

    // called by borrower
    // should we block seller from calling this?
    function buyout(Auction calldata auction) external {
        
        // Pull buyoutPrice from caller/borrower to seller
        DAI.safeTransferFrom(msg.sender, auction.seller, auction.buyoutPrice);

        // Start Loan
        startLoan();
    }

    // called by borrower
    // should we block seller from calling this?
    function bid(uint tokenId, uint newBid) external {

        // Get highestBidder
        Bidder storage highestBidder = auctions[tokenId].highestBidder;

        // Ensure newBid > highestBidder
        require(newBid > highestBidder.bid, "new bid must be greater than current highest bid");

        // Refund highestBidder
        DAI.safeTransfer(highestBidder.addr, highestBidder.bid);

        // Pull bid from caller/borrower to protocol
        DAI.safeTransferFrom(msg.sender, address(this), newBid);

        // Update highestBidder
        highestBidder.addr = msg.sender;
        highestBidder.bid = newBid;
    }

    // called by seller
    function acceptBid(Auction calldata auction) external {
        require(msg.sender == auction.seller, "only seller can accept bids");

        // Pull bid from protocol to seller
        DAI.safeTransferFrom(address(this), auction.seller, auction.highestBidder.bid);

        // Start Loan
        startLoan();
    }

    function startLoan() private {

    }
}