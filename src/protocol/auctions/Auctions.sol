// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";

import "forge-std/console.sol";

contract Auctions is IAuctions, Status {

    using SafeERC20 for IERC20;

    function bid(uint tokenId, uint propertyValue, uint downPayment, uint maxDurationMonths) external {
        require(prosperaNftContract.isEResident(msg.sender), "only eResidents can bid");
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

        console.log("ab0");

        // Get tokenIdBids
        Bid[] storage tokenIdBids = _bids[tokenId];

        // Ensure bid is actionable
        require(bidActionable(tokenIdBids[bidIdx]), "bid not actionable");

        // Get status
        Status status = status(tokenId);

        console.log("ab1");

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

        console.log("ab2");

        // Get tokenIdLastBid
        Bid memory tokenIdLastBid = tokenIdBids[tokenIdBids.length - 1];

        // Write tokenIdLastBid over bidIdx
        tokenIdBids[bidIdx] = tokenIdLastBid;

        // Remove tokenIdLastBid
        tokenIdBids.pop();
    }

    function _acceptNoneBid(uint tokenId, uint bidIdx) private {

        console.log("anb1");

        // Get nftOwner
        address nftOwner = prosperaNftContract.ownerOf(tokenId);
        
        require(status(tokenId) == Status.None, "status not none"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == nftOwner, "caller not nftOwner");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        console.log("anb2");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        console.log("anb3");

        // Protocol takes fees
        protocolMoney += saleFee;

        console.log("anb4");

        // Ensure propertyValue covers saleFee
        require(_bid.propertyValue >= saleFee, "propertyValue doesn't cover saleFee"); // Question: interest will rise over time. Too risky?

        console.log("anb5");

        // Calculate equity
        uint equity = _bid.propertyValue - saleFee;

        console.log("anb6");

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
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptMortgageBid(uint tokenId, uint bidIdx) private {

        console.log("amb1");

        // Get loan
        Loan memory loan = _loans[tokenId];

        require(status(tokenId) == Status.Mortgage, "status not mortgage"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == loan.borrower, "caller not borrower");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        console.log("amb2");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));

        console.log("amb3");

        // Protocol takes fees
        protocolMoney += saleFee;

        console.log("amb4");

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        console.log("amb5");
        totalPrincipal -= loan.unpaidPrincipal;
        console.log("amb6");
        totalDeposits += interest;
        console.log("amb7");
        // maxTotalUnpaidInterest -= interest;
        console.log("amb8");

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
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptDefaultBid(uint tokenId, uint bidIdx) private {

        console.log("adb1");

        // Get loan
        Loan memory loan = _loans[tokenId];

        require(status(tokenId) == Status.Default, "status not default"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        require(msg.sender == loan.borrower, "caller not borrower");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

       console.log("adb2");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread));
        uint defaultFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_defaultFeeSpread));

        console.log("adb3");

        // Protocol takes fees
        protocolMoney += saleFee + defaultFee;

        console.log("adb4");

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        console.log("adb5");
        totalPrincipal -= loan.unpaidPrincipal;
        console.log("adb6");
        totalDeposits += interest;
        console.log("adb7");
        // maxTotalUnpaidInterest -= interest;
        console.log("adb8");

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee + defaultFee;

        console.log("adb9");

        // Ensure propertyValue covers debt
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        console.log("adb10");

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        console.log("adb11");

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
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }

    function _acceptForeclosureBid(uint tokenId, uint bidIdx) private {

        console.log("afb1");

        // Get loan
        Loan memory loan = _loans[tokenId];
        
        require(status(tokenId) == Status.Foreclosurable, "status not foreclosurable"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        // require(msg.sender == address(this), "caller not protocol"); Todo: figure this out later

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        console.log("afb2");

        // Calculate fees
        uint saleFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        uint defaultFee = fromUD60x18(toUD60x18(_bid.propertyValue).mul(_defaultFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?

        console.log("afb3");

        // Protocol takes fees
        protocolMoney += saleFee + defaultFee;

        console.log("afb4");

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        // Update pool (lenders get paidFirst)
        console.log("afb5");
        totalPrincipal -= loan.unpaidPrincipal;
        console.log("afb6");
        totalDeposits += interest;
        console.log("afb7");
        // console.log("maxTotalUnpaidInterest:", maxTotalUnpaidInterest);
        console.log("interest:", interest);
        // maxTotalUnpaidInterest -= interest;
        console.log("afb8");

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee + defaultFee;

        console.log("afb9");

        // Ensure propertyValue covers principal + interest + fees
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        console.log("afb10");

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        console.log("afb11");

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
                    (_bid.bidder, tokenId, principal, _bid.maxDurationMonths)
                )
            );
            require(success, "startLoan delegateCall failed");
        }
    }
}