// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../loanStatus/LoanStatus.sol";
import "../borrowing/IBorrowing.sol";

contract Auctions is IAuctions, LoanStatus {

    using SafeERC20 for IERC20;

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) external {
        require(tangibleNft.exists(tokenId), "tokenId doesn't exist");
        require(_isResident(msg.sender), "only residents can bid"); // Note: NFT transfer to non-resident bidder would fail anyways, but I think its best to not invalid bids for Sellers
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(loanMonths > 0 && loanMonths <= _maxLoanMonths, "unallowed loanMonths");

        // Validate ltv
        require(propertyValue > 0, "propertyValue must be > 0");
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(_maxLtv), "ltv cannot exceed maxLtv");

        // Validate minSalePrice
        require(propertyValue >= _minSalePrice(_debts[tokenId].loan), "propertyValue must cover minSalePrice");

        // Pull downPayment from bidder
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment,
                loanMonths: loanMonths,
                accepted: false
            })
        );
    }

    // Question: should bidder be able to cancel a pending bid?
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
    
    // Todo: implement bid/neededLoan locks
    function acceptBid(uint tokenId, uint idx) external {
        require(msg.sender == tangibleNft.ownerOf(tokenId), "only nft owner can accept bid"); // Question: maybe PAC should be able too (for foreclosures?)
        require(!pendingBid[tokenId], "nft already has pending bid"); // Note: only allowing owner to have one accepted bid at a time should simplify things

        // Get bid
        Bid storage _bid = _bids[tokenId][idx];

        // Lock principal (propertyValue - downPayment)
        locked += _bid.propertyValue - _bid.downPayment;

        // Accept bid
        _bid.accepted = true;

        // Change nft's pendingBid to true
        pendingBid[tokenId] = true;
    }

    // Todo: implement bid/neededLoan unlocks
    function confirmSale(uint tokenId, uint idx) external onlyRole(GSP) {

        // Get bid
        Bid memory _bid = _bids[tokenId][idx];

        // Ensure bid was accepted
        require(_bid.accepted, "bid not yet accepted by nft owner");

        // Debt Transfer NFT from seller to bidder
        IBorrowing(address(this)).debtTransfer({
            tokenId: tokenId,
            seller: tangibleNft.ownerOf(tokenId),
            _bid: _bid
        });

        // Delete accepted bid
        deleteBid(_bids[tokenId], idx);

        // Change nft's pendingBid back to false
        pendingBid[tokenId] = false;

        // Unlock principal (propertyValue - downPayment)
        locked -= _bid.propertyValue - _bid.downPayment;
    }

    // Todo: implement bid/neededLoan unlocks
    function cancelSale(uint tokenId, uint idx) external {
        require(msg.sender == tangibleNft.ownerOf(tokenId) || hasRole(GSP, msg.sender), "only nft owner or admin can cancel sale");

        // Get bid
        Bid memory _bid = _bids[tokenId][idx];

        // Ensure bid was accepted
        require(_bid.accepted, "bid not yet accepted by nft owner");

        // Change nft's pendingBid back to false
        pendingBid[tokenId] = false;

        // Unlock principal (propertyValue - downPayment)
        locked -= _bid.propertyValue - _bid.downPayment;
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