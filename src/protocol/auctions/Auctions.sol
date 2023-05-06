// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

contract Auctions is IAuctions, Status {

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

        // Get tokenIdBids
        Bid[] storage tokenIdBids = _bids[tokenId];

        // Ensure bid is actionable
        require(bidActionable(tokenIdBids[bidIdx]), "bid not actionable");

        // Get status
        Status status = status(tokenId);

        if (status == Status.None) {
            _acceptNoneBid(tokenId, bidIdx);

        } else if (status == Status.Mortgage) {
            _acceptMortgageBid(tokenId, bidIdx);

        } else if (status == Status.Default) {
            _acceptDefaultBid(tokenId, bidIdx);

        } else if (status == Status.Foreclosurable) {
            _acceptForeclosureBid(tokenId, bidIdx);
            
        } else {
            revert("invalid status");
        }

        // Get tokenIdLastBid
        Bid memory tokenIdLastBid = tokenIdBids[tokenIdBids.length - 1];

        // Write tokenIdLastBid over bidIdx
        tokenIdBids[bidIdx] = tokenIdLastBid;

        // Remove tokenIdLastBid
        tokenIdBids.pop();
    }

    function _acceptNoneBid(uint tokenId, uint bidIdx) private {

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(tokenId);
        
        require(status(tokenId) == Status.None, "status not none"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == nftOwner, "caller not nftOwner");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Protocol takes fees
        protocolMoney += saleFee;

        // Ensure propertyValue covers saleFee
        require(_bid.propertyValue >= saleFee, "propertyValue doesn't cover saleFee"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - saleFee;

        // Send equity to nftOwner
        USDC.safeTransfer(nftOwner, equity);

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT from nftOwner to bidder
            prosperaNftContract.safeTransferFrom(nftOwner, _bid.bidder, tokenId);

        // If loan bid
        } else {

            // Pull NFT from nftOwner to protocol
            prosperaNftContract.safeTransferFrom(nftOwner, address(this), tokenId);

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptMortgageBid(uint tokenId, uint bidIdx) private {

        // Get loan
        Loan memory loan = _loans[tokenId];

        require(status(tokenId) == Status.Mortgage, "status not mortgage"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == loan.borrower, "caller not borrower");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        // Protocol takes fees
        protocolMoney += saleFee;

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        maxTotalUnpaidInterest -= interest;

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee;

        // Ensure propertyValue covers debt
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt + fees"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        // Send equity to loan.borrower
        USDC.safeTransfer(loan.borrower, equity);

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);

        // If loan bid
        } else {

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptDefaultBid(uint tokenId, uint bidIdx) private {

        // Get loan
        Loan memory loan = _loans[tokenId];

        require(status(tokenId) == Status.Default, "status not default"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == loan.borrower, "caller not borrower");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));
        uint defaultFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_defaultFeeSpread));

        // Protocol takes fees
        protocolMoney += saleFee + defaultFee;

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        maxTotalUnpaidInterest -= interest;

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee + defaultFee;

        // Ensure propertyValue covers debt
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        // Send equity to loan.borrower
        USDC.safeTransfer(loan.borrower, equity);

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);

        // If loan bid
        } else {

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptForeclosureBid(uint tokenId, uint bidIdx) private {

        // Get loan
        Loan memory loan = _loans[tokenId];
        
        require(status(tokenId) == Status.Foreclosurable, "status not foreclosurable"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == address(this), "caller not protocol");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        uint defaultFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_defaultFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?

        // Protocol takes fees
        protocolMoney += saleFee + defaultFee;

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        maxTotalUnpaidInterest -= interest;

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee + defaultFee;

        // Ensure propertyValue covers principal + interest + fees
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        // Send equity to loan.borrower
        USDC.safeTransfer(loan.borrower, equity);

        // If bid
        if (_bid.propertyValue == _bid.downPayment) {
            
            // Send NFT to bidder
            prosperaNftContract.safeTransferFrom(address(this), _bid.bidder, tokenId);

        // If loan bid
        } else {

            // Calculate principal
            uint principal = _bid.propertyValue - _bid.downPayment;

            // start new loan
            (bool success, ) = logicTargets[IBorrowing.startLoan.selector].delegatecall(
                abi.encodeCall(
                    IBorrowing.startLoan,
                    (tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }
}