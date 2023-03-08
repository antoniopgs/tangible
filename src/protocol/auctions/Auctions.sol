// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
// import "../pool/Pool.sol";
import "../../config/config/ConfigUser.sol";
import "../vault/vault/IVault.sol";
import "../borrowing/IBorrowing.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "../types/Property.sol";

contract Auctions is IAuctions, ConfigUser {

    // Links
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // ethereum
    // IERC721 prosperaNftContract;

    using SafeERC20 for IERC20;

    function bid(TokenId tokenId, uint propertyValue, uint downPayment) external {

        // Calculate bid ltv
        uint ltv = 1 - (downPayment / propertyValue);

        // Ensure bid ltv <= maxLtv
        require(ltv <= config.getUD60x18(MAX_LTV), "ltv cannot exceed maxLtv");

        // Pull downPayment bidder to protocol
        IERC20(config.getAddress(USDC)).safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to vault
        IVault(config.getAddress(VAULT)).addBid(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment
            })
        );
    }

    function acceptBid(TokenId tokenId, Idx _bidIdx) external {

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(tokenId);

        // Ensure caller is nft owner
        require(msg.sender == nftOwner, "only nft owner can accept bids");

        // Get bid
        Bid memory _bid = bids[tokenId][bidIdx];

        // If regular bid
        if (_bid.downPayment == _bid.propertyValue) {

            // Send bid.propertyValue from protocol to seller
            IERC20(config.getAddress(USDC)).safeTransferFrom(address(this), nftOwner, _bid.propertyValue); // DON'T FORGET TO CHARGE FEE LATER

            // Send NFT from protocol to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId); // NFT COMES LATER
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // Send bid.propertyValue from protocol to seller
            IERC20(config.getAddress(USDC)).safeTransferFrom(address(this), nftOwner, _bid.propertyValue); // DON'T FORGET TO CHARGE FEE LATER

            // Start Loan
            IBorrowing(config.getAddress(BORROWING)).startLoan({
                tokenId: tokenId,
                propertyValue: _bid.propertyValue,
                principal: _bid.propertyValue - _bid.downPayment,
                borrower: _bid.bidder
            });
        }
    }

    function cancelBid(TokenId tokenId, Idx bidIdx) external {

        // Get nft bids
        Bid[] storage nftBids = bids[tokenId];

        // Get bidToCancel
        Bid memory bidToCancel = nftBids[bidIdx];

        // Ensure caller is bidder
        require(msg.sender == bidToCancel.bidder, "only bidder can cancel his bid");

        // Get lastBid
        Bid memory lastBid = nftBids[nftBids.length - 1];

        // Write lastBid over bidIdx
        nftBids[bidIdx] = lastBid;

        // Remove lastBid
        nftBids.pop();

        // Send bidToCancel.downPayment from protocol to bidder
        IERC20(config.getAddress(USDC)).safeTransferFrom(address(this), bidToCancel.bidder, bidToCancel.downPayment);
    }

    function loanBidActionable(Bid memory _bid) public view returns(bool) {

        // Calculate loanBid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate loanBid ltv
        uint ltv = principal / _bid.propertyValue; // FIX LATER

        // Return actionability
        return ltv <= config.getUD60x18(MAX_LTV) && IPool(config.getAddress(POOL)).availableLiquidity() >= principal;
    }
}