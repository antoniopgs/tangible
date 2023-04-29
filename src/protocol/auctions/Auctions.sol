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

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate saleFee
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // If regular bid
        if (_bid.downPayment == _bid.propertyValue) {

            // Send NFT from nftOwner to bidder
            prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, tokenId);
        
        // If loan bid
        } else {

            // Ensure loan bid is actionable
            require(loanBidActionable(_bid), "loanBid not actionable");

            // If status(nft) == None, nft shouldn't be in system (so pull it)
            if (status == Status.None) {

                // Pull NFT from nftOwner to protocol
                prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId);
            }

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

    function acceptNoneBid(uint tokenId, uint bidIdx) external {
        require(status(_loans[tokenId]) == Status.None, "");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Accept bid
        _acceptBid({
            tokenId: tokenId,
            bidIdx: bidIdx,
            associatedLoanPrincipal: 0, // Note: no loan
            associatedLoanInterest: 0, // Note: no loan
            protocolFees: saleFee
        })
    }

    function acceptMortgageBid(uint tokenId, uint bidIdx) external {
        require(status(_loans[tokenId]) == Status.Mortgage, "");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Accept bid
        _acceptBid({
            tokenId: tokenId,
            bidIdx: bidIdx,
            associatedLoanPrincipal: loan.unpaidPrincipal,
            associatedLoanInterest: accruedInterest(loan),
            protocolFees: saleFee
        })
    }

    function acceptDefaultBid(uint tokenId, uint bidIdx) external {
        require(status(_loans[tokenId]) == Status.Default, "");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));
        uint defaultFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_defaultFeeSpread));

        // Accept bid
        _acceptBid({
            tokenId: tokenId,
            bidIdx: bidIdx,
            associatedLoanPrincipal: loan.unpaidPrincipal,
            associatedLoanInterest: accruedInterest(loan),
            protocolFees: saleFee + defaultFee
        })
    }

    function _acceptBid(uint tokenId, uint bidIdx, uint associatedLoanPrincipal, uint associatedLoanInterest, uint protocolFees) private {
        
        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];
        
        // Ensure bid is actionable
        require(bidActionable(_bid), "bid not actionable");

        // Update pool (lenders get paidFirst)
        totalPrincipal -= associatedLoanPrincipal;
        totalDeposits += associatedLoanInterest;
        maxTotalUnpaidInterest -= associatedLoanInterest;

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Protocol takes fees (protocol gets paid second)
        protocolMoney += protocolFees;

        // Ensure propertyValue covers principal + interest + fees
        require(_bid.propertyValue >= associatedLoanPrincipal + associatedLoanInterest + protocolFees, "propertyValue doesn't cover debt + fees"); // Question: associatedLoanInterest will rise over time. Too risky?

        // Calculate rest
        uint rest = _bid.propertyValue - associatedLoanPrincipal - associatedLoanInterest - protocolFees;

        // Get status
        Status status = status(tokenId);

        // If None, send rest to nftOwner
        if (status == Status.None) {
            address nftOwner = prosperaNftContract.ownerOf(tokenId);
            require(msg.sender == nftOwner, "caller not nftOwner");
            USDC.safeTransfer(nftOwner, rest);
        
        // If Mortgage, Default or Foreclosurable, send rest to loan.borrower
        } else {
            USDC.safeTransfer(_loans[tokenId].borrower, rest);

            // If Foreclosurable, caller must be protocol
            if (status == Status.Foreclosurable) {
                require(msg.sender == address(this), "caller not protocol");
            
            // If Mortgage or Default, caller must be borrower
            } else {
                require(msg.sender == _loans[tokenId].borrower, "caller not borrower");
            }
        }
        
        // If bid (no loan)
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);
        }
    }
}