// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IAuctions.sol";
import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../borrowing/borrowing/IBorrowing.sol";
import { convert } from "@prb/math/src/UD60x18.sol";

import "forge-std/console.sol";

contract AcceptForeclosurable is Status {

    using SafeERC20 for IERC20;

    function acceptForeclosurableBid(uint tokenId, uint bidIdx) external {

        console.log("afb1");

        // Get loan
        Loan memory loan = _loans[tokenId];

        console.log("afb2");
        
        require(status(tokenId) == Status.Foreclosurable, "status not foreclosurable"); // Question: maybe remove this? (since it's checked in acceptBid() and this function is private?)
        // require(msg.sender == address(this), "caller not protocol"); Todo: figure this out later

        console.log("afb3");

        // Get bid
        Bid memory _bid = _bids[tokenId][bidIdx];

        console.log("afb4");

        // Calculate fees
        uint saleFee = convert(convert(_bid.propertyValue).mul(_saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        uint defaultFee = convert(convert(_bid.propertyValue).mul(_defaultFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?

        console.log("afb5");

        // Protocol takes fees
        protocolMoney += saleFee + defaultFee;

        console.log("afb6");

        // assert(associatedLoanInterest <= _loans[tokenId].maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?

        console.log("afb7");

        // Calculate interest
        uint interest = accruedInterest(tokenId);

        console.log("afb8");

        // Update pool (lenders get paidFirst)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        // maxTotalUnpaidInterest -= interest;

        console.log("afb9");

        // Calculate debt
        uint debt = loan.unpaidPrincipal + interest + saleFee + defaultFee;

        console.log("afb10");

        // Ensure propertyValue covers principal + interest + fees
        require(_bid.propertyValue >= debt, "propertyValue doesn't cover debt"); // Question: interest will rise over time. Too risky?

        console.log("afb11");

        // Calculate equity
        uint equity = _bid.propertyValue - debt;

        console.log("afb12");

        // Send equity to loan.borrower
        USDC.safeTransfer(loan.borrower, equity);

        console.log("afb13");

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