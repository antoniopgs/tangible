// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

import "./AcceptNone.sol";
import "./AcceptMortgage.sol";
import "./AcceptDefault.sol";
import "./AcceptForeclosurable.sol";

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

        emit NewBid(msg.sender, tokenId, propertyValue, downPayment, maxDurationMonths, ltv);
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

        emit CancelBid(msg.sender, tokenId, bidIdx);

        // Todo: use deleteBid() here
    }

    function acceptBid(uint tokenId, uint bidIdx) external {

        // Get tokenIdBids
        Bid[] storage tokenIdBids = _bids[tokenId];

        // Ensure bid is actionable
        require(_bidActionable(tokenIdBids[bidIdx]), "bid not actionable");

        // Get status
        Status status = status(tokenId);

        if (status == Status.None) {
            (bool success, ) = logicTargets[AcceptNone.acceptNoneBid.selector].delegatecall(
                abi.encodeCall(
                    AcceptNone.acceptNoneBid,
                    (tokenId, bidIdx)
                )
            );
            require(success, "acceptNoneBid() call failed");

        } else if (status == Status.Mortgage) {
            (bool success, ) = logicTargets[AcceptMortgage.acceptMortgageBid.selector].delegatecall(
                abi.encodeCall(
                    AcceptMortgage.acceptMortgageBid,
                    (tokenId, bidIdx)
                )
            );
            require(success, "acceptMortgageBid() call failed");

        } else if (status == Status.Default) {
            (bool success, ) = logicTargets[AcceptDefault.acceptDefaultBid.selector].delegatecall(
                abi.encodeCall(
                    AcceptDefault.acceptDefaultBid,
                    (tokenId, bidIdx)
                )
            );
            require(success, "acceptDefaultBid() call failed");

        } else if (status == Status.Foreclosurable) {
            (bool success, ) = logicTargets[AcceptForeclosurable.acceptForeclosurableBid.selector].delegatecall(
                abi.encodeCall(
                    AcceptForeclosurable.acceptForeclosurableBid,
                    (tokenId, bidIdx)
                )
            );
            require(success, "acceptForeclosurableBid() call failed");
            
        } else {
            revert("invalid status");
        }

        // Delete accepted bid
        deleteBid(tokenIdBids, bidIdx);

        emit AcceptBid(tokenId, bidIdx, status);
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