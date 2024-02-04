// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

// Inheritance
import "./PoolBase.sol";

// Other
import "../tokens/PropertyNft.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PoolAuctions is PoolBase {

    PropertyNft immutable PROPERTY;

    struct Loan {
        UD60x18 ratePerSecond;
        UD60x18 paymentPerSecond;
        uint unpaidPrincipal;
        uint startTime;
        uint maxDurationSeconds;
        uint lastPaymentTime;
    }

    struct Bid {
        address bidder;
        uint propertyValue;
        uint downPayment;
        uint loanMonths;
    }

    UD60x18 internal _maxLtv;
    uint internal _maxLoanMonths;

    mapping(uint tokenId => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft later
    mapping(uint tokenId => Loan) internal _loans;
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it

    using SafeERC20 for IERC20;

    // Question: what if nft has no debt? it could still use an auction mechanism, right? openSea could be used, but so could this...
    function _bid(uint tokenId, uint propertyValue, uint downPayment, uint loanMonths) internal returns (uint newBidIdx) {
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
        require(propertyValue >= loan.unpaidPrincipal + _accruedInterest(loan), "propertyValue must cover sellerDebt"); // Question: do I need this?

        // Pull downPayment from bidder
        UNDERLYING.safeTransferFrom(msg.sender, address(this), downPayment);
        // vault.deposit(downPayment);

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
    function _cancelBid(uint tokenId, uint idx) internal {

        // Get tokenBids
        Bid[] storage tokenBids = _bids[tokenId];

        // Get bidToRemove
        Bid memory bidToRemove = tokenBids[idx];

        // Ensure caller is bidder
        require(msg.sender == bidToRemove.bidder, "only bidder can remove his bid");

        // Return downPayment to bidder
        UNDERLYING.safeTransfer(bidToRemove.bidder, bidToRemove.downPayment);
        // vault.withdraw(bidToRemove.downPayment);

        // Delete bid
        _deleteBid(tokenBids, idx);
    }

    function _isResident(address addr) private view returns (bool) {
        return _addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }

    function _accruedInterest(Loan memory loan) private view returns(uint) {
        return convert(convert(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function _deleteBid(Bid[] storage tokenBids, uint idx) private {

        // Get tokenLastBid
        Bid memory tokenLastBid = tokenBids[tokenBids.length - 1];

        // Write tokenLastBid over idx to remove
        tokenBids[idx] = tokenLastBid;

        // Remove tokenLastBid
        tokenBids.pop();
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(convert(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }
}