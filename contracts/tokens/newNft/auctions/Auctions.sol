// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../debts/Debts.sol";
import "../pool/Pool.sol";
import "../residents/Residents.sol";

contract Auctions is IAuctions, Debts, Residents {

    using SafeERC20 for IERC20;

    function bid(uint tokenId, uint propertyValue, uint loanMonths) external {
        bid(tokenId, propertyValue, propertyValue, loanMonths);
    }

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) public {
        _requireMinted(tokenId);
        require(_isResident(msg.sender), "only residents can bid");
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(loanMonths > 0 && loanMonths <= maxLoanMonths, "unallowed loanMonths");

        // Validate ltv
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Bidder increases protocol's allowance
        USDC.safeIncreaseAllowance(address(this), downPayment);

        // Add bid to tokenId bids
        bids[tokenId].push(
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
        Bid[] storage tokenBids = bids[tokenId];

        // Get bidToRemove
        Bid memory bidToRemove = tokenBids[idx];

        // Ensure caller is bidder
        require(msg.sender == bidToRemove.bidder, "only bidder can remove his bid");

        // Bidder decreases protocol's allowance by bidToRemove's downPayment
        USDC.safeDecreaseAllowance(address(this), bidToRemove.downPayment);

        // Delete bid
        deleteBid(tokenBids, idx);
    }

    function acceptBid(uint tokenId, uint idx) external {
        require(msg.sender == ownerOf(tokenId), "only token owner can accept bid"); // Question: maybe PAC should be able too (for foreclosures?)

        // Get Bid
        Bid memory _bid = bids[tokenId][idx];

        // Ensure bid is actionable
        require(_bidActionable(_bid), "bid not actionable");

        // Debt Transfer NFT from seller to bidder
        debtTransfer({
            tokenId: tokenId,
            _bid: _bid
        });

        // Delete accepted bid
        deleteBid(bids[tokenId], idx);
    }

    function deleteBid(Bid[] storage tokenBids, uint idx) private {

        // Get tokenLastBid
        Bid memory tokenLastBid = tokenBids[tokenBids.length - 1];

        // Write tokenLastBid over idx to remove
        tokenBids[idx] = tokenLastBid;

        // Remove tokenLastBid
        tokenBids.pop();
    }

    function _bidActionable(Bid memory _bid) internal view returns(bool) {
        return _bid.downPayment == _bid.propertyValue || loanBidActionable(_bid);
    }

    function loanBidActionable(Bid memory _bid) private view returns(bool) {

        // Calculate loanBid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate loanBid ltv
        UD60x18 ltv = convert(principal).div(convert(_bid.propertyValue));

        // Return actionability
        return ltv.lte(maxLtv) && principal <= _availableLiquidity(); // Note: LTV already validated in bid(), but re-validate it here (because admin may have updated it)
    }
}