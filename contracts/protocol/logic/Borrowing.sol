// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/logic/IBorrowing.sol";
import "./loanStatus/LoanStatus.sol";
import "./interest/InterestConstant.sol";

contract Borrowing is IBorrowing, LoanStatus, InterestConstant {

    using SafeERC20 for IERC20;

    function _startNewMortgage(Loan storage loan, uint principal, uint maxDurationMonths) private {

        // Get ratePerSecond
        UD60x18 ratePerSecond = IInterest(address(this)).calculateNewRatePerSecond(utilization());

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

        // Update pool
        _totalPrincipal += principal;
        assert(_totalPrincipal <= _totalDeposits);

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
        pool.payDebt(repayment, interest);

        // Log
        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    // Admin Functions
    function foreclose(uint tokenId) external onlyOwner {

        require(_status(_loans[tokenId]) == Status.Default, "no default");

        // Get idx
        uint idx = highestActionableBid(tokenId);

        debtTransfer({
            tokenId: tokenId,
            seller: PROPERTY.ownerOf(tokenId),
            _bid: _bids[tokenId][idx]
        }); // Note: might need to change debtTransfer() visibility
    }

    // Note: pulling buyer's downPayment to address(this) is safer, because buyer doesn't need to approve seller (which could let him run off with money)
    // Question: if active mortgage is being paid off with a new loan, the pool is paying itself, so money flows should be simpler...
    // Todo: figure out where to send otherDebt
    // Note: bid() now pulls downPayment, so no need to pull it here
    // Todo: add/implement otherDebt later?
    // Todo: figure out access restriction
    function debtTransfer(uint tokenId, address seller, Bid memory _bid) public { // Todo: maybe move elsewhere (like ERC721) to not need onlySelf

        // Get bid info
        // address seller /* = ownerOf(tokenId) */;
        uint salePrice = _bid.propertyValue;
        uint downPayment = _bid.downPayment;

        // Get loan info
        Loan storage loan = _loans[tokenId];
        uint interest = _accruedInterest(loan);

        // Ensure bid is actionable
        require(_bidActionable(_bid, _minSalePrice(loan)), "bid not actionable");

        // Calculate saleFee
        UD60x18 saleFeeSpread = _status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        uint saleFee = convert(convert(salePrice).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?

        // Pay Pool
        pool.payDebt(loan.unpaidPrincipal, interest);

        // Protocol Charges Fees
        protocolMoney += saleFee;

        // Send sellerEquity (salePrice - sellerDebt) to seller
        // sellerDebt = loan.unpaidPrincipal + interest + saleFee
        UNDERLYING.safeTransfer(seller, salePrice - loan.unpaidPrincipal - interest - saleFee);

        // Clear seller/caller debt
        loan.unpaidPrincipal = 0;

        // Send nft from seller to bidder
        PROPERTY.safeTransferFrom(seller, _bid.bidder, tokenId);

        // If bidder needs loan
        if (downPayment < salePrice) {

            // Start new Loan
            _startNewMortgage({
                loan: loan,
                principal: salePrice - downPayment,
                maxDurationMonths: _bid.loanMonths
            });
        }
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
        apr = IInterest(address(this)).calculateNewRatePerSecond(utilization()).mul(convert(SECONDS_IN_YEAR));
    }
}