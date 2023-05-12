// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

contract Auctions is IAuctions, Status {

    using SafeERC20 for IERC20;

    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external {
        require(prosperaNftContract.isEResident(msg.sender), "only eResidents can bid");
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(maxDurationMonths >= 1 && maxDurationMonths <= maxDurationMonthsCap, "unallowed maxDurationMonths");

        // Validate ltv
        UD60x18 ltv = convert(uint(1)).sub(convert(downPayment).div(convert(propertyValue)));
        require(ltv.lte(maxLtv), "ltv cannot exceed maxLtv");

        // Todo: Ensure tokenId exists?

        // Pull downPayment from caller to protocol
        USDC.safeTransferFrom(msg.sender, address(this), downPayment);

        // Add bid to tokenId bids
        _bids[tokenId].push(
            Bid({
                bidder: msg.sender,
                propertyValue: propertyValue,
                downPayment: downPayment,
                maxDurationMonths: maxDurationMonths
            })
        );
    }

    function cancelBid(uint tokenId, uint bidIdx) external {

        // Todo: Ensure tokenId exists?

        // Get propertyBids
        Bid[] storage propertyBids = _bids[tokenId];

        // Get bidToRemove
        Bid memory bidToRemove = propertyBids[bidIdx];

        // Ensure caller is bidder
        require(msg.sender == bidToRemove.bidder, "only bidder can remove his bid");

        // Get last propertyLastBid
        Bid memory propertyLastBid = propertyBids[propertyBids.length - 1];

        // Write propertyLastBid over bidToRemove
        propertyBids[bidIdx] = propertyLastBid;

        // Remove lastPropertyBid
        propertyBids.pop();

        // Send bidToRemove's downPayment from protocol to bidder
        USDC.safeTransfer(bidToRemove.bidder, bidToRemove.downPayment);
    }

    function acceptBid(uint tokenId, uint bidIdx) external {

        // Get tokenIdBids
        Bid[] storage tokenIdBids = _bids[tokenId];

        // Ensure bid is actionable
        require(bidActionable(tokenIdBids[bidIdx]), "bid not actionable");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate saleFee
        uint saleFee = convert(convert(_bid.propertyValue).mul(_saleFeeSpread));
        uint debt = saleFee;
        protocolMoney += saleFee;

        // Get status
        Status status = status(tokenId);

        if (status == Status.None) {
            require(msg.sender == prosperaNftContract.ownerOf(tokenId), "caller not nftOwner");
            _acceptNoneBid(tokenId, bidIdx);

        } else if (status == Status.Mortgage) {
            require(msg.sender == loan.borrower, "caller not borrower");
            _acceptMortgageBid(tokenId, bidIdx);

        } else if (status == Status.Default) {
            require(msg.sender == loan.borrower, "caller not borrower");
            _acceptDefaultBid(tokenId, bidIdx);

        } else if (status == Status.Foreclosurable) {
            // require(msg.sender == address(this), "caller not protocol");
            _acceptForeclosureBid(tokenId, bidIdx);
            
        } else {
            revert("invalid status");
        }

        if (status == Status.Mortgage || status == Status.Default || status == Status.Foreclosurable) {

            // Get loan
            Loan memory loan = _loans[tokenId];

            // Calculate interest
            uint interest = accruedInterest(tokenId);

            // Update debt
            debt += loan.unpaidPrincipal + interest;

            // Update Pool
            totalPrincipal -= loan.unpaidPrincipal;
            totalDeposits += interest;
            // maxTotalUnpaidInterest -= interest;

            if (status == Status.Default || status = Status.Foreclosurable) {

                // Calculate defaultFee
                uint defaultFee = convert(convert(_bid.propertyValue).mul(_defaultFeeSpread));
                debt += defaultFee;
                protocolMoney += defaultFee;
            }

            // Send equity to loan.borrower
            USDC.safeTransfer(loan.borrower, equity);

        } else if (status == Status.None) {

            // Send equity to nftOwner
            USDC.safeTransfer(nftOwner, equity);
        }

        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {

            if (status == Status.None) {

                // Send NFT from nftOwner to bidder
                prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, tokenId);

            } else {

                // Send NFT to bidder
                prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);
            }
        
        // If loan bid
        } else {

            if (status == Status.None) {

                // Pull NFT from nftOwner to protocol
                prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId);
            }

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }

        // Delete accepted bid
        deleteBid(tokenIdBids, bidIdx);
    }

    function deleteBid(Bid[] storage tokenIdBids, uint idxToRemove) private {

        // Get tokenIdLastBid
        Bid memory tokenIdLastBid = tokenIdBids[tokenIdBids.length - 1];

        // Write tokenIdLastBid over idxToRemove
        tokenIdBids[idxToRemove] = tokenIdLastBid;

        // Remove tokenIdLastBid
        tokenIdBids.pop();
    }
}