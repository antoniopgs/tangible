// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IAuctions.sol";
import "./loanStatus/LoanStatus.sol";
import "../../../interfaces/logic/IBorrowing.sol";

import { console } from "forge-std/console.sol";

contract Auctions is IAuctions, LoanStatus {

    using SafeERC20 for IERC20;

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) external returns (uint newBidIdx) {
        require(PROPERTY.ownerOf(tokenId) != address(0), "tokenId doesn't exist"); // Note: might need changes if NFTs become burnable
        require(_isResident(msg.sender), "only residents can bid"); // Note: NFT transfer to non-resident bidder would fail anyways, but I think its best to not invalid bids for Sellers
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(loanMonths > 0 && loanMonths <= _maxLoanMonths, "unallowed loanMonths");

        // Validate ltv
        require(propertyValue > 0, "propertyValue must be > 0");
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(_maxLtv), "ltv cannot exceed maxLtv");

        // Get Loan
        Loan memory loan = _loans[tokenId];

        // Validate minSalePrice
        require(propertyValue >= loan.unpaidPrincipal + _accruedInterest(loan), "propertyValue must cover sellerDebt");

        // Pull downPayment from bidder
        // UNDERLYING.safeTransferFrom(msg.sender, address(this), downPayment);
        vault.deposit(downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment,
                loanMonths: loanMonths
            })
        );

        // Return newBidIdx
        newBidIdx = _bids[tokenId].length - 1;
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
        UNDERLYING.safeTransfer(bidToRemove.bidder, bidToRemove.downPayment);

        // Delete bid
        _deleteBid(tokenBids, idx);
    }
    
    // Todo: implement bid/neededLoan locks
    function acceptBid(uint tokenId, uint idx) external {
        require(msg.sender == PROPERTY.ownerOf(tokenId), "only nft owner can accept bid"); // Question: maybe PAC should be able too (for foreclosures?)

        // Get bid
        Bid storage _bid = _bids[tokenId][idx];

        console.log("ab1");

        // Debt Transfer NFT from seller to bidder
        IBorrowing(address(this)).debtTransfer({
            tokenId: tokenId,
            _bid: _bid
        });

        console.log("ab1");

        // Delete accepted bid
        _deleteBid(_bids[tokenId], idx);
    }
}