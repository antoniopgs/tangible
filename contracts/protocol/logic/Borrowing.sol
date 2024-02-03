// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IBorrowing.sol";
import "./loanStatus/LoanStatus.sol";
import "./interest/InterestConstant.sol";

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

        // Pull underlying from caller
        UNDERLYING.safeTransferFrom(msg.sender, address(this), payment);

        // Calculate repayment
        uint repayment = payment >= interest ? payment - interest : 0;

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.lastPaymentTime = block.timestamp;

        // Pay pool
        vault.payDebt(repayment, interest);

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

    // Note: pulling buyer's downPayment to address(this) is safer, because buyer doesn't need to approve seller (which could let him run off with money)
    // Question: if active mortgage is being paid off with a new loan, the pool is paying itself, so money flows should be simpler...
    // Todo: figure out where to send otherDebt
    // Note: bid() now pulls downPayment, so no need to pull it here
    // Todo: add/implement otherDebt later?
    // Todo: figure out access restriction
    function debtTransfer(uint tokenId, Bid memory _bid) public { // Todo: maybe move elsewhere (like ERC721) to not need onlySelf

        // Get seller
        address seller = PROPERTY.ownerOf(tokenId);

        // Get bid info
        uint salePrice = _bid.propertyValue;
        uint downPayment = _bid.downPayment;

        // Get loan
        Loan storage loan = _loans[tokenId];

        // Get interest
        uint interest = _accruedInterest(loan);

        // Calculate sellerDebt
        uint sellerDebt = loan.unpaidPrincipal + interest;

        // Ensure bid is actionable
        require(_bidActionable(_bid, sellerDebt), "bid not actionable");

        // Pay Pool
        vault.payDebt(loan.unpaidPrincipal, interest);

        // Calculate sellerEquity
        uint sellerEquity = salePrice - sellerDebt;

        // Send sellerEquity to seller
        UNDERLYING.safeTransfer(seller, sellerEquity);

        // Calculate principal
        uint principal = salePrice - downPayment;

        // Borrow from pool
        vault.borrow(seller, principal);

        // Send nft from seller to bidder
        PROPERTY.safeTransferFrom(seller, _bid.bidder, tokenId);

        // If bidder needs loan
        if (downPayment < salePrice) {

            // Start new Loan
            _startNewMortgage({
                loan: loan,
                principal: principal,
                maxDurationMonths: _bid.loanMonths
            });

        } else {

            // Clear nft debt
            loan.unpaidPrincipal = 0;
        }
    }

    function debtTransfer2(
        uint tokenId,
        address buyer,
        address seller,
        uint buyerDownPayment,
        uint buyerPrincipal,
        uint sellerRepayment,
        uint sellerInterest
    ) external {

        // Update totalDeposits
        totalDeposits += sellerInterest;

        // Calculate sellerDebt
        uint sellerDebt = sellerRepayment + sellerInterest;

        // Settle pool and seller
        if (buyerPrincipal >= sellerDebt) {

            // Update pool
            totalPrincipal += buyerPrincipal - sellerRepayment; // Note: no underflow (sellerRepayment <= sellerDebt <= buyerPrincipal)

            // Push from pool to seller
            UNDERLYING_TOKEN.safeTransfer(seller, buyerPrincipal - sellerDebt);

        } else {

            // Update pool
            totalPrincipal -= sellerRepayment - buyerPrincipal; // Note: MIGHT UNDERFLOW (buyerPrincipal < sellerDebt AND sellerDebt >= sellerRepayment)

            // Pull from seller to pool
            UNDERLYING_TOKEN.safeTransferFrom(seller, address(this), sellerDebt - buyerPrincipal);
        }
        
        // Send buyerDownPayment from buyer to seller
        UNDERLYING_TOKEN.safeTransferFrom(buyer, seller, buyerDownPayment);

        // Transfer NFT from seller to buyer
        NFT.safeTransferFrom(seller, buyer, tokenId);
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