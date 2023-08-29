// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IDebt.sol";
import "../state/State.sol";
// import "../../../protocol/borrowing/status/Status.sol";

contract Debt is IDebt, State /*, Status, */ {

    // function startNewMortgage() external {

    //     // 1. Buyer sends downPayment to seller
    //     USDC.safeTransferFrom(msg.sender, seller, downPayment);

    //     // 2. Pool sends principal to seller
    //     USDC.safeTransfer(seller, principal);

    //     // 3. Admin transfers token from seller to buyer
    //     nft.safeTransferFrom(seller, buyer, tokenId);
    // }

    // User Functions
    function startNewMortgage(uint tokenId) external { // Todo: MUST WORK ON TRANSFER

    }

    function payMortgage(uint tokenId, uint payment) external {
        require(status(tokenId) == Status.Mortgage, "nft has no active mortgage");

        // Get Loan
        Loan storage loan = _loans[tokenId];

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
        require(status(tokenId) == Status.Default, "no default");
        require(redeemable(tokenId), "redemption window is over");

        // Get Loan
        Loan memory loan = debts[tokenId].loan;

        // Calculate interest
        uint interest = _accruedInterest(loan);

        // Calculate defaulterDebt & redemptionFee
        uint defaulterDebt = loan.unpaidPrincipal + interest;
        uint redemptionFee = convert(convert(defaulterDebt).mul(_redemptionFeeSpread));

        // Redeem (pull defaulter's entire debt + redemptionFee)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt + redemptionFee); // Note: anyone can redeem on behalf of defaulter // Question: actually, shouldn't the defaulter be the only one able to redeem? // Note: maybe better to separate this from other contracts which also pull USDC, to compartmentalize approvals

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;

        emit RedeemLoan(msg.sender, tokenId, interest, defaulterDebt, redemptionFee, block.timestamp);
    }

    // Admin Functions
    function refinance(uint tokenId) external onlyRole(GSP) {

    }

    function foreclose(uint tokenId) external onlyRole(PAC) {

    }

    function updateOtherDebt(uint tokenId, string calldata motive) external onlyRole(GSP) {

    }

    // Views
    function _accruedInterest(Loan memory loan) internal view returns(uint) {
        return convert(convert(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(convert(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) private pure returns(UD60x18 paymentPerSecond) {

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

    function status(Loan memory loan) private view returns (Status) {
        
        if (loan.unpaidPrincipal == 0) {
            return Status.ResidentOwned;

        } else {
            
            if (defaulted(loan)) {
                return Status.Default;

            } else {
                return Status.Mortgage;
            }
        }
    }

    function defaulted(Loan memory loan) private view returns(bool) {

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(loan);

        if (_loanCompletedMonths == 0) {
            return false;
        }

        // Calculate loanMaxDurationMonths
        uint loanMaxDurationMonths = loan.maxDurationSeconds / yearSeconds * yearMonths;

        // If loan exceeded allowed months
        if (_loanCompletedMonths > loanMaxDurationMonths) {
            return true;
        }

        return loan.unpaidPrincipal > principalCap(loan, _loanCompletedMonths);
    }

    // Note: truncates on purpose (to enforce payment after monthSeconds, but not every second)
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        uint completedMonths = (block.timestamp - loan.startTime) / monthSeconds;
        uint _loanMaxMonths = loanMaxMonths(loan);
        return completedMonths > _loanMaxMonths ? _loanMaxMonths : completedMonths;
    }

    function loanMaxMonths(Loan memory loan) private pure returns (uint) {
        return yearMonths * loan.maxDurationSeconds / yearSeconds;
    }

    function principalCap(Loan memory loan, uint month) private pure returns(uint cap) {

        // Ensure month doesn't exceed loanMaxDurationMonths
        require(month <= loanMaxMonths(loan), "month must be <= loanMaxDurationMonths");

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = convert(int(elapsedSeconds)).sub(convert(int(loan.maxDurationSeconds))).sub(convert(int(1)));

        // Calculate numerator
        SD59x18 z = convert(int(1)).sub(intoSD59x18(convert(uint(1)).add(loan.ratePerSecond)).pow(negExponent));
        UD60x18 numerator = intoUD60x18(intoSD59x18(loan.paymentPerSecond).mul(z));

        // Calculate cap
        cap = convert(numerator.div(loan.ratePerSecond));
    }

    function redeemable(Loan memory loan) private view returns(bool) {
        uint timeSinceDefault = block.timestamp - defaultTime(loan);
        return timeSinceDefault <= redemptionWindow;
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function defaultTime(Loan memory loan) private view returns (uint _defaultTime) {

        uint completedMonths = loanCompletedMonths(loan);

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) { // Todo: reduce gas costs

            uint completedMonthPrincipalCap = principalCap(loan, i);
            uint prevCompletedMonthPrincipalCap = i == 1 ? loan.unpaidPrincipal : principalCap(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _defaultTime = loan.startTime + (i * monthSeconds);
            }
        }

        assert(_defaultTime > 0);
    }
}