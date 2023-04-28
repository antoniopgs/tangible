// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract Auctions is IAuctions, State {

    using SafeERC20 for IERC20;

    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external {
        require(downPayment <= propertyValue, "downPayment cannot exceed propertyValue");
        require(maxDurationMonths >= 1 && maxDurationMonths <= maxDurationMonthsCap, "unallowed maxDurationMonths");

        // Validate ltv
        UD60x18 ltv = toUD60x18(1).sub(toUD60x18(downPayment).div(toUD60x18(propertyValue)));
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

        // who should get sale money
        // if none: ownerOf(tokenId)
        // if mortage: loans(tokenId).borrower;
        // if default: loans(tokenId).borrower
        // if foreclosurable: loans(tokenId).borrower

        // Get status
        Status memory status = status(tokenId);

        if (status == Status.None) {
            require(msg.sender == prosperaNftContract.ownerOf(tokenId), "caller not owner");

        } else if (status == Status.Mortgage) {
            require(msg.sender == _loans[tokenId].borrower, "caller not borrower");

        } else if (status == Status.Default) {
            require(msg.sender == _loans[tokenId].borrower, "caller not borrower");

        } else if (status == Status.Foreclosurable) {
            require(msg.sender == address(this), "caller not protocol");
        }

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate saleFee
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(tokenId); // IF DEFAULT/MORTGAGE/FORECLOSURE, this will be the protocol itself

        // Send (bid.propertyValue - saleFee) to nftOwner
        USDC.safeTransfer(nftOwner, _bid.propertyValue - saleFee);

        // Add saleFee to protocolMoney
        protocolMoney += saleFee;

        // If regular bid
        if (_bid.downPayment == _bid.propertyValue) {

            // Send NFT from nftOwner to bidder
            prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, tokenId);
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId);

            // Start Loan (via delegate call)
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, _bid.propertyValue - _bid.downPayment, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }
}