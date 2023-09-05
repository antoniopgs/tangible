// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../loanStatus/LoanStatus.sol";
import "../borrowingInfo/BorrowingInfo.sol";
import "../interest/Interest.sol";
import "../onlySelf/OnlySelf.sol";
import { Status } from "../../types/Types.sol";

import { console } from "forge-std/console.sol";

contract Borrowing is IBorrowing, LoanStatus, BorrowingInfo, Interest, OnlySelf {

    using SafeERC20 for IERC20;

    function startNewMortgage(Loan storage loan, uint principal, uint maxDurationMonths) private {

        // Get ratePerSecond
        UD60x18 ratePerSecond = borrowerRatePerSecond(_utilization());

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * monthSeconds;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);
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

        // Update pool
        _totalPrincipal += principal;
        assert(_totalPrincipal <= _totalDeposits);

        // Emit Event
        emit StartLoan(ratePerSecond, paymentPerSecond, principal, maxDurationMonths, currentTime);
    }

    // User Functions
    function payMortgage(uint tokenId, uint payment) external {

        // Get Loan
        Loan storage loan = _debts[tokenId].loan;

        // Ensure there's an active mortgage
        require(_status(loan) == Status.Mortgage, "nft has no active mortgage");

        // Calculate interest
        uint interest = _accruedInterest(loan);

        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment >= interest, "payment must be >= interest"); // Question: maybe don't calculate repayment if payment < interest?

        // Bound payment
        if (payment > loan.unpaidPrincipal + interest) {
            payment = loan.unpaidPrincipal + interest;
        }

        // Pull payment from msg.sender
        USDC.safeTransferFrom(msg.sender, address(this), payment); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Calculate repayment
        console.log("payment:", payment);
        console.log("interest:", interest);
        uint repayment = payment - interest; // Todo: Add payLoanFee // Question: should payLoanFee come off the interest to lenders? Or only come off the borrower's repayment?
        console.log("post");

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.lastPaymentTime = block.timestamp;

        // Protocol charges interestFee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
        protocolMoney += interestFee;

        // Update pool
        _totalPrincipal -= repayment;
        _totalDeposits += interest - interestFee;

        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    // Todo: who gets nft?
    function redeemMortgage(uint tokenId) external {

        // Get Loan
        Loan memory loan = _debts[tokenId].loan;

        // Ensure default & redeemable
        require(_status(loan) == Status.Default, "no default");
        require(_redeemable(tokenId), "redemption window is over");

        // Calculate interest
        uint interest = _accruedInterest(loan);

        // Calculate defaulterDebt & redemptionFee
        uint defaulterDebt = loan.unpaidPrincipal + interest;
        uint redemptionFee = convert(convert(defaulterDebt).mul(_redemptionFeeSpread));

        // Redeem (pull defaulter's entire debt + redemptionFee)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt + redemptionFee); // Note: anyone can redeem on behalf of defaulter // Question: actually, shouldn't the defaulter be the only one able to redeem? // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Protocol charges interestFee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
        protocolMoney += interestFee;

        // Update pool
        _totalPrincipal -= loan.unpaidPrincipal;
        _totalDeposits += interest - interestFee;

        emit RedeemLoan(msg.sender, tokenId, interest, defaulterDebt, redemptionFee, block.timestamp);
    }

    // Admin Functions
    function foreclose(uint tokenId) external onlyRole(PAC) {

        require(_status(_debts[tokenId].loan) == Status.Default, "no default");
        require(!_redeemable(tokenId), "redemption window not over");

        // Get idx
        uint idx = highestActionableBid(tokenId);

        debtTransfer({
            tokenId: tokenId,
            seller: tangibleNft.ownerOf(tokenId),
            _bid: _bids[tokenId][idx]
        }); // Note: might need to change debtTransfer() visibility
    }

    function increaseOtherDebt(uint tokenId, uint amount, string calldata motive) external onlyRole(GSP) {
        _debts[tokenId].otherDebt += amount;
        emit DebtIncrease(tokenId, amount, motive, block.timestamp);
    }

    function decreaseOtherDebt(uint tokenId, uint amount, string calldata motive) external onlyRole(GSP) {
        require(_debts[tokenId].otherDebt >= amount, "amount must be <= otherDebt");
        _debts[tokenId].otherDebt -= amount;
        emit DebtDecrease(tokenId, amount, motive, block.timestamp);
    }

    // Note: pulling buyer's downPayment to address(this) is safer, because buyer doesn't need to approve seller (which could let him run off with money)
    // Question: if active mortgage is being paid off with a new loan, the pool is paying itself, so money flows should be simpler...
    // Todo: figure out where to send otherDebt
    // Note: bid() now pulls downPayment, so no need to pull it here
    // Todo: add/implement otherDebt later?
    function debtTransfer(uint tokenId, address seller, Bid memory _bid) public /* onlySelf */ { // Todo: maybe move elsewhere (like ERC721) to not need onlySelf

        // Get bid info
        // address seller /* = ownerOf(tokenId) */;
        uint salePrice = _bid.propertyValue;
        uint downPayment = _bid.downPayment;

        // Get loan info
        Loan storage loan = _debts[tokenId].loan;
        uint interest = _accruedInterest(loan);

        // Ensure bid is actionable
        require(_bidActionable(_bid, _minSalePrice(loan)), "bid not actionable");

        // Calculate interest Fee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));

        // Calculate saleFee
        UD60x18 saleFeeSpread = _status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        uint saleFee = convert(convert(salePrice).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?

        // Update Pool (pay off lenders)
        _totalPrincipal -= loan.unpaidPrincipal;
        _totalDeposits += interest - interestFee;

        // Protocol Charges Fees
        protocolMoney += interestFee + saleFee;

        // Send sellerEquity (salePrice - sellerDebt) to seller
        // sellerDebt = loan.unpaidPrincipal + interest + saleFee
        USDC.safeTransfer(seller, salePrice - loan.unpaidPrincipal - interest - saleFee);

        // Clear seller/caller debt
        loan.unpaidPrincipal = 0;

        // Send nft from seller to bidder
        tangibleNft.safeTransferFrom(seller, _bid.bidder, tokenId);

        // If bidder needs loan
        if (downPayment < salePrice) {

            // Start new Loan
            startNewMortgage({
                loan: loan,
                principal: salePrice - downPayment,
                maxDurationMonths: _bid.loanMonths
            });
        }
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) internal pure returns(UD60x18 paymentPerSecond) {

        // Calculate x
        // - (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // - (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log(MAX_UD60x18) / log(1 + ratePerSecond)
        // - maxDurationMonths <= (log(MAX_UD60x18) / log(1 + ratePerSecond)) / monthSeconds // Note: ratePerSecond depends on util (so solve for maxDurationMonths)
        // - maxDurationMonths <= log(MAX_UD60x18) / (monthSeconds * log(1 + ratePerSecond))
        UD60x18 x = convert(uint(1)).add(ratePerSecond).powu(maxDurationSeconds);

        // principal * ratePerSecond * x <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18 / (principal * ratePerSecond)
        // maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_(MAX_UD60x18 / (principal * ratePerSecond))
        // maxDurationMonths * monthSeconds <= log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)
        // maxDurationMonths <= (log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)) / monthSeconds
        // maxDurationMonths <= log(MAX_UD60x18 / (principal * ratePerSecond)) / (monthSeconds * log(1 + ratePerSecond))
        
        // Calculate paymentPerSecond
        paymentPerSecond = convert(principal).mul(ratePerSecond).mul(x).div(x.sub(convert(uint(1))));
    }
}