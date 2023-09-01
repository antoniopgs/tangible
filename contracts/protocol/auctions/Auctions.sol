// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../auctionsInfo/AuctionsInfo.sol";
import "../borrowing/IBorrowing.sol";

contract Auctions is IAuctions, AuctionsInfo {

    using SafeERC20 for IERC20;

    function bid(uint tokenId, uint propertyValue, uint loanMonths) external {
        loanBid(tokenId, propertyValue, propertyValue, loanMonths);
    }

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function loanBid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) public {
        require(tangibleNft.exists(tokenId), "tokenId doesn't exist");
        require(_isResident(msg.sender), "only residents can bid"); // Note: NFT transfer to non-resident bidder would fail anyways, but I think its best to not invalid bids for Sellers
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(loanMonths > 0 && loanMonths <= maxLoanMonths, "unallowed loanMonths");

        // Validate ltv
        require(propertyValue > 0, "propertyValue must be > 0");
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Pull downPayment from bidder
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment,
                loanMonths: loanMonths
            })
        );
    }

    // Note: no need to ensure tokenId exists. if it doesn't, bidder should be address(0)
    function cancelBid(uint tokenId, uint idx) external {

        // Get tokenBids
        Bid[] storage tokenBids = _bids[tokenId];

        // Get bidToRemove
        Bid memory bidToRemove = tokenBids[idx];

        // Ensure caller is bidder
        require(msg.sender == bidToRemove.bidder, "only bidder can remove his bid");

        // Return downPayment to bidder
        USDC.safeTransfer(bidToRemove.bidder, bidToRemove.downPayment);

        // Delete bid
        deleteBid(tokenBids, idx);
    }

    function acceptBid(uint tokenId, uint idx) external {
        require(msg.sender == tangibleNft.ownerOf(tokenId), "only token owner can accept bid"); // Question: maybe PAC should be able too (for foreclosures?)

        // Get Bid
        Bid memory _bid = _bids[tokenId][idx];

        // Ensure bid is actionable
        require(_bidActionable(_bid), "bid not actionable");

        // Debt Transfer NFT from seller to bidder
        IBorrowing(address(this)).debtTransfer({
            tokenId: tokenId,
            seller: tangibleNft.ownerOf(tokenId),
            _bid: _bid
        });

        // Delete accepted bid
        deleteBid(_bids[tokenId], idx);
    }

    function deleteBid(Bid[] storage tokenBids, uint idx) private {

        // Get tokenLastBid
        Bid memory tokenLastBid = tokenBids[tokenBids.length - 1];

        // Write tokenLastBid over idx to remove
        tokenBids[idx] = tokenLastBid;

        // Remove tokenLastBid
        tokenBids.pop();
    }
}