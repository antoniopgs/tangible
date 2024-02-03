// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IBorrowing.sol";
import "./loanStatus/LoanStatus.sol";
import "./interest/InterestConstant.sol";

import "forge-std/console.sol";

contract Borrowing is IBorrowing, LoanStatus, InterestConstant {

    using SafeERC20 for IERC20;

    function _startNewMortgage(Loan storage loan, uint principal, uint maxDurationMonths) private {

        // Get ratePerSecond
        UD60x18 ratePerSecond = IInterest(address(this)).calculateNewRatePerSecond(vault.utilization());

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * SECONDS_IN_MONTH;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = _calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);
        require(paymentPerSecond.gt(convert(uint(0))), "paymentPerSecond must be > 0"); // Note: Maybe move to calculatePaymentPerSecond()?

        // Get currentTime
        uint currentTime = block.timestamp;

        // Update Loan
        loan.ratePerSecond = ratePerSecond;
        loan.paymentPerSecond = paymentPerSecond;
        loan.unpaidPrincipal = principal;
        loan.startTime = currentTime;
        loan.maxDurationSeconds = maxDurationSeconds;
        loan.lastPaymentTime = currentTime; // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now

        // Validate currentPrincipalCap
        assert(currentPrincipalCap(loan) == loan.unpaidPrincipal);

        // Emit Event
        emit StartLoan(ratePerSecond, paymentPerSecond, principal, maxDurationMonths, currentTime);
    }

    // User Functions
    function payMortgage(uint tokenId, uint payment) external {

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Ensure there's an active mortgage
        require(_status(loan) == Status.Mortgage, "nft has no active mortgage");

        // Calculate interest
        uint interest = _accruedInterest(loan);

        // Bound payment
        if (payment > loan.unpaidPrincipal + interest) {
            payment = loan.unpaidPrincipal + interest;
        }

        // Calculate repayment
        uint repayment = payment >= interest ? payment - interest : 0;

        // Pay pool
        vault.payDebt(msg.sender, repayment, interest);

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.lastPaymentTime = block.timestamp;

        // Log
        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    // Admin Functions
    function foreclose(uint tokenId) external onlyOwner {

        require(_status(_loans[tokenId]) == Status.Default, "no default");

        // Get idx
        uint idx = highestActionableBid(tokenId);
        
        // Note: might need to change debtTransfer() visibility
        debtTransfer({
            tokenId: tokenId,
            _bid: _bids[tokenId][idx]
        });

        // Delete bid
        _deleteBid(_bids[tokenId], idx);
    }
    
    // Note: bid() already pulls downPayment (no need to pull it here)
    // Todo: figure out access restriction
    function debtTransfer(uint tokenId, Bid memory _bid) public {

        address seller = PROPERTY.ownerOf(tokenId);
        uint buyerPrincipal = _bid.propertyValue - _bid.downPayment;
        Loan storage loan = _loans[tokenId];

        console.log("dt2");
        
        // Call Vault
        vault.fooBar({
            seller: seller,
            sellerRepayment: loan.unpaidPrincipal,
            sellerInterest: _accruedInterest(loan),
            buyerPrincipal: buyerPrincipal,
            buyerDownPayment: _bid.downPayment
        });

        console.log("dt3");

        // If buyer needs loan
        if (buyerPrincipal > 0) {

            console.log("dt3.1");

            // Start new Loan
            _startNewMortgage({
                loan: loan,
                principal: buyerPrincipal,
                maxDurationMonths: _bid.loanMonths
            });

            console.log("dt3.2");

        } else {

            // Clear nft debt
            loan.unpaidPrincipal = 0;
        }

        console.log("dt4");

        // Transfer NFT from seller to buyer/bidder
        PROPERTY.safeTransferFrom(seller, _bid.bidder, tokenId);

        console.log("dt4");
    }

    function _calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) internal pure returns(UD60x18 paymentPerSecond) {

        // Calculate x
        // - (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // - (1 + ratePerSecond) ** (maxDurationMonths * SECONDS_IN_MONTH) <= MAX_UD60x18
        // - maxDurationMonths * SECONDS_IN_MONTH <= log_(1 + ratePerSecond)_MAX_UD60x18
        // - maxDurationMonths * SECONDS_IN_MONTH <= log(MAX_UD60x18) / log(1 + ratePerSecond)
        // - maxDurationMonths <= (log(MAX_UD60x18) / log(1 + ratePerSecond)) / SECONDS_IN_MONTH // Note: ratePerSecond depends on util (so solve for maxDurationMonths)
        // - maxDurationMonths <= log(MAX_UD60x18) / (SECONDS_IN_MONTH * log(1 + ratePerSecond))
        UD60x18 x = convert(uint(1)).add(ratePerSecond).powu(maxDurationSeconds);

        // principal * ratePerSecond * x <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** (maxDurationMonths * SECONDS_IN_MONTH) <= MAX_UD60x18
        // (1 + ratePerSecond) ** (maxDurationMonths * SECONDS_IN_MONTH) <= MAX_UD60x18 / (principal * ratePerSecond)
        // maxDurationMonths * SECONDS_IN_MONTH <= log_(1 + ratePerSecond)_(MAX_UD60x18 / (principal * ratePerSecond))
        // maxDurationMonths * SECONDS_IN_MONTH <= log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)
        // maxDurationMonths <= (log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)) / SECONDS_IN_MONTH
        // maxDurationMonths <= log(MAX_UD60x18 / (principal * ratePerSecond)) / (SECONDS_IN_MONTH * log(1 + ratePerSecond))
        
        // Calculate paymentPerSecond
        paymentPerSecond = convert(principal).mul(ratePerSecond).mul(x).div(x.sub(convert(uint(1))));
    }

    function borrowerApr() external view returns(UD60x18 apr) {
        apr = IInterest(address(this)).calculateNewRatePerSecond(vault.utilization()).mul(convert(SECONDS_IN_YEAR));
    }
}