// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../debt/Debt.sol";
import "../pool/Pool.sol";
import "../residents/Residents.sol";

contract Auctions is IAuctions, Debt, Pool, Residents {

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

    // Note: pulling buyer's downPayment to address(this) is safer, because buyer doesn't need to approve seller (which could let him run off with money)
    // Question: if active mortgage is being paid off with a new loan, the pool is paying itself, so money flows should be simpler...
    // Todo: figure out where to send otherDebt
    function debtTransfer(uint tokenId, Bid memory _bid) private {
        
        // Get bid info
        address seller = ownerOf(tokenId);
        address buyer = _bid.bidder;
        uint salePrice = _bid.propertyValue;
        uint downPayment = _bid.downPayment;

        // 1. Pull downPayment from buyer
        USDC.safeTransferFrom(buyer, address(this), downPayment); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // 2. Pull principal from protocol
        uint principal = salePrice - downPayment; // Note: will be 0 if no loan (which is fine)
        USDC.safeTransferFrom(protocol, address(this), principal); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals
        totalPrincipal += principal;

        // 3. Get Loan
        Debt storage debt = debts[tokenId];
        Loan storage loan = debt.loan;
        uint interest = _accruedInterest(loan);

        // Protocol charges Interest Fee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
        protocolMoney += interestFee;

        // Update Pool (pay off lenders)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest - interestFee;

        // Protocol charges saleFee
        UD60x18 saleFeeSpread = status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        uint saleFee = convert(convert(salePrice).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        protocolMoney += saleFee;

        // 3. Send sellerEquity (salePrice - unpaidPrincipal - interest - otherDebt) to seller
        uint sellerDebt = loan.unpaidPrincipal + interest + saleFee + interestFee + debt.otherDebt;
        require(salePrice >= sellerDebt, "salePrice must cover sellerDebt");
        USDC.safeTransfer(seller, salePrice - sellerDebt);

        // 5. Clear seller/caller debt
        loan.unpaidPrincipal = 0;
        debt.otherDebt = 0;

        // 3. Send nft from seller to buyer
        safeTransferFrom(seller, buyer, tokenId);

        // If buyer needs loan
        if (principal > 0) {
            startNewMortgage({
                loan: loan,
                principal: principal,
                maxDurationMonths: _bid.loanMonths
            });
        }
    }
}