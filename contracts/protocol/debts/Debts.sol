// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IDebts.sol";
import "../debtsInfo/DebtsInfo.sol";
import "../nftStatus/NftStatus.sol";
import "../interest/Interest.sol";

contract Debts is IDebts, DebtsInfo, NftStatus, Interest {

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
        totalPrincipal += principal;
        assert(totalPrincipal <= totalDeposits);

        // Emit Event
        emit StartLoan(ratePerSecond, paymentPerSecond, principal, maxDurationMonths, currentTime);
    }

    // User Functions
    function payMortgage(uint tokenId, uint payment) external {

        // Get Loan
        Loan storage loan = debts[tokenId].loan;

        // Ensure there's an active mortgage
        require(status(loan) == Status.Mortgage, "nft has no active mortgage");

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
        uint repayment = payment - interest; // Todo: Add payLoanFee // Question: should payLoanFee come off the interest to lenders? Or only come off the borrower's repayment?

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.lastPaymentTime = block.timestamp;

        // Protocol charges interestFee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));
        protocolMoney += interestFee;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest - interestFee;

        emit PayLoan(msg.sender, tokenId, payment, interest, repayment, block.timestamp, loan.unpaidPrincipal == 0);
    }

    function redeemMortgage(uint tokenId) external {

        // Get Loan
        Loan memory loan = debts[tokenId].loan;

        // Ensure default & redeemable
        require(status(loan) == Status.Default, "no default");
        require(redeemable(loan), "redemption window is over");

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
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest - interestFee;

        emit RedeemLoan(msg.sender, tokenId, interest, defaulterDebt, redemptionFee, block.timestamp);
    }

    // Admin Functions
    function foreclose(uint tokenId, uint idx) external onlyRole(PAC) {
        debtTransfer(tokenId, bids[tokenId][idx]);
    }

    function increaseOtherDebt(uint tokenId, uint amount, string calldata motive) external onlyRole(GSP) {
        debts[tokenId].otherDebt += amount;
        emit DebtIncrease(tokenId, amount, motive, block.timestamp);
    }

    function decreaseOtherDebt(uint tokenId, uint amount, string calldata motive) external onlyRole(GSP) {
        require(debts[tokenId].otherDebt >= amount, "amount must be <= otherDebt");
        debts[tokenId].otherDebt -= amount;
        emit DebtDecrease(tokenId, amount, motive, block.timestamp);
    }

    // Note: pulling buyer's downPayment to address(this) is safer, because buyer doesn't need to approve seller (which could let him run off with money)
    // Question: if active mortgage is being paid off with a new loan, the pool is paying itself, so money flows should be simpler...
    // Todo: figure out where to send otherDebt
    function debtTransfer(uint tokenId, Bid memory _bid) internal {
        
        // Get bid info
        address seller /* = ownerOf(tokenId) */;
        address buyer = _bid.bidder;
        uint salePrice = _bid.propertyValue;
        uint downPayment = _bid.downPayment;

        // Pull downPayment from buyer
        USDC.safeTransferFrom(buyer, address(this), downPayment); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Pull principal from protocol
        uint principal = salePrice - downPayment; // Note: will be 0 if no loan (which is fine)
        USDC.safeTransferFrom(protocol, address(this), principal); // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals
        totalPrincipal += principal;

        // Get Loan
        Debt storage debt = debts[tokenId];
        Loan storage loan = debt.loan;
        uint interest = _accruedInterest(loan);

        // Calculate interest Fee
        uint interestFee = convert(convert(interest).mul(_interestFeeSpread));

        // Update Pool (pay off lenders)
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest - interestFee;

        // Calculate saleFee
        UD60x18 saleFeeSpread = status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        uint saleFee = convert(convert(salePrice).mul(saleFeeSpread)); // Question: should this be off propertyValue, or defaulterDebt?
        
        // Protocol Charges Fees
        protocolMoney += interestFee + saleFee;

        // Send sellerEquity (salePrice - unpaidPrincipal - interest - otherDebt) to seller
        uint sellerDebt = loan.unpaidPrincipal + interest + interestFee + saleFee + debt.otherDebt;
        require(salePrice >= sellerDebt, "salePrice must cover sellerDebt");
        USDC.safeTransfer(seller, salePrice - sellerDebt);

        // Clear seller/caller debt
        loan.unpaidPrincipal = 0;
        debt.otherDebt = 0;

        // Send nft from seller to buyer
        safeTransferFrom(seller, buyer, tokenId);

        // If buyer used loan
        if (principal > 0) {

            // Start new Loan
            startNewMortgage({
                loan: loan,
                principal: principal,
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