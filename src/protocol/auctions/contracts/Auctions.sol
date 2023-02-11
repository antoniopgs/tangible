// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IAuctions.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AuctionClosing.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../../mortgages/contracts/Lending.sol";

abstract contract Auctions is IAuctions, AuctionClosing, ERC721Holder {

    using SafeERC20 for IERC20;

    function startAuction(uint tokenId) external {

        // Pull NFT from seller
        prosperaNftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Store auction
        Auction storage auction = auctions[tokenId];
        auction.seller = msg.sender;
    }

    // function bid(uint tokenId, UD60x18 bidAmount) external { // called by borrower // should we block seller from calling this?

    //     // Pull bid from caller/bidder to protocol
    //     USDC.safeTransferFrom(msg.sender, address(this), bidAmount);

    //     // Add Bidder to auction bidders
    //     auctions[tokenId].bidders.push(
    //         Bid({
    //             bidder: msg.sender,
    //             amount: bidAmount,
    //             loan: false
    //         })
    //     );
    // }

    function bid(uint tokenId, UD60x18 propertyValue, UD60x18 downPayment) external { // called by borrower // should we block seller from calling this?

        // Calculate bid ltv
        UD60x18 ltv = toUD60x18(1).sub(downPayment.div(propertyValue));

        // Ensure bid ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Pull downPayment from caller/borrower to protocol
        USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(downPayment));

        // Add Bidder to auction bidders
        auctions[tokenId].bids.push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment
            })
        );
    }

    function pullBid(uint tokenId) external {
        // require(, "only bidder can pull his bid");
    }

    function acceptLoanBid(uint tokenId, uint bidIdx) external { // called by seller

    }

    function loanBidActionable() public view returns(bool) {
        // availableLiquidity >= principal
    }

    function acceptBid(uint tokenId, uint bidIdx) external {

        // Get auction
        Auction memory auction = auctions[tokenId];

        // Ensure caller is seller
        require(msg.sender == auction.seller, "only seller can accept bids");

        // Get bid
        Bid memory _bid = auction.bids[bidIdx];

        // Send bid.amount from protocol to seller
        USDC.safeTransferFrom(address(this), auction.seller, fromUD60x18(_bid.propertyValue)); // DON'T FORGET TO CHARGE FEE LATER // DO WE STILL NEED OPTION & CLOSING PERIODS FOR NON-LOAN BIDS?

        // Send NFT from protocol to bidder
        prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId); // DO WE STILL NEED OPTION & CLOSING PERIODS FOR NON-LOAN BIDS?

        // Start optionPeriod
        auction.optionPeriodEnd = block.timestamp + optionPeriodDuration;
    }
}