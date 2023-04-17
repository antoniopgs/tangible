// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../state/state/State.sol";
import { fromUD60x18 } from "@prb/math/UD60x18.sol";
import { SD59x18, toSD59x18 } from "@prb/math/SD59x18.sol";
import { intoUD60x18 } from "@prb/math/sd59x18/Casting.sol";
import { intoSD59x18 } from "@prb/math/ud60x18/Casting.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Borrowing is IBorrowing, State {

    // Libs
    using SafeERC20 for IERC20;

    // Functions
    function startLoan(uint tokenId, uint principal, /* uint borrowerAprPct, */ uint maxDurationMonths) external {
        require(status(tokenId) == Status.None, "nft already in system");
        require(principal <= availableLiquidity(), "principal must be <= availableLiquidity");
        require(maxDurationMonths >= 1, "loan maxDuration must be at least 1 month");

        // Calculate ratePerSecond
        // UD60x18 ratePerSecond = toUD60x18(borrowerAprPct).div(toUD60x18(100)).div(toUD60x18(yearSeconds));
        UD60x18 ratePerSecond = borrowerRatePerSecond();

        // Calculate maxDurationSeconds
        uint maxDurationSeconds = maxDurationMonths * monthSeconds;

        // Calculate paymentPerSecond
        UD60x18 paymentPerSecond = calculatePaymentPerSecond(principal, ratePerSecond, maxDurationSeconds);

        // Calculate maxCost
        uint maxCost = fromUD60x18(paymentPerSecond.mul(toUD60x18(maxDurationSeconds)));

        // Calculate maxUnpaidInterest
        uint maxUnpaidInterest = maxCost - principal;
        
        _loans[tokenId] = Loan({
            borrower: msg.sender,
            ratePerSecond: ratePerSecond,
            paymentPerSecond: paymentPerSecond,
            startTime: block.timestamp,
            unpaidPrincipal: principal,
            maxUnpaidInterest: maxUnpaidInterest,
            maxDurationSeconds: maxDurationSeconds,
            lastPaymentTime: block.timestamp // Note: no payment here, but needed so lastPaymentElapsedSeconds only counts from now
        });

        // Update pool
        totalPrincipal += principal;
        maxTotalInterestOwed += maxUnpaidInterest;
    }

    function payLoan(uint tokenId, uint payment) external {
        require(status(tokenId) == Status.Mortgage, "nft has no active mortgage");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Calculate interest
        uint interest = accruedInterest(loan);
        //require(payment <= loan.unpaidPrincipal + interest, "payment must be <= unpaidPrincipal + interest");
        //require(payment => interest, "payment must be => interest"); // Question: maybe don't calculate repayment if payment < interest?

        // Calculate repayment
        uint repayment = payment - interest;

        // Update loan
        loan.unpaidPrincipal -= repayment;
        loan.maxUnpaidInterest -= interest;
        loan.lastPaymentTime = block.timestamp;

        // Update pool
        totalPrincipal -= repayment;
        totalDeposits += interest;
        maxTotalInterestOwed -= interest;

        // If loan is paid off
        if (loan.unpaidPrincipal == 0) {

            // Clear out loan
            loan.borrower = address(0);
        }
    }

    function redeem(uint tokenId) external {
        require(status(tokenId) == Status.Default, "no default");

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Todo: Ensure State == Default

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest;

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(msg.sender, address(this), defaulterDebt); // Note: anyone can redeem on behalf of defaulter

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Todo: Clearout loan
        loan.borrower = address(0);
    }

    function foreclose(uint tokenId, uint salePrice) external {
        require(status(tokenId) == Status.Foreclosurable, "nft not foreclosurable");

        // Todo: Pull salePrice?

        // Get Loan
        Loan storage loan = _loans[tokenId];

        // Todo: Ensure State == Foreclosurable

        // Calculate interest
        uint interest = accruedInterest(loan);

        // Calculate defaulterDebt
        uint defaulterDebt = loan.unpaidPrincipal + interest; // Todo: add fees later

        // Ensure salePrice covers defaulterDebt + fees
        require(salePrice >= defaulterDebt, "salePrice must >= defaulterDebt"); // Question: minSalePrice will rise over time. Too risky?

        // Update pool
        totalPrincipal -= loan.unpaidPrincipal;
        totalDeposits += interest;
        // assert(interest <= loan.maxUnpaidInterest); // Note: actually, if borrower defaults, can't he pay more interest than loan.maxUnpaidInterest?
        maxTotalInterestOwed -= loan.maxUnpaidInterest; // Note: maxTotalInterestOwed -= accruedInterest + any remaining unpaid interest (so can use loan.maxUnpaidInterest)

        // Calculate defaulterEquity
        uint defaulterEquity = salePrice - defaulterDebt;

        // Send defaulterEquity to defaulter
        USDC.safeTransfer(loan.borrower, defaulterEquity);

        // Todo: Clearout loan
        loan.borrower = address(0);
    }

    function accruedInterest(Loan memory loan) private view returns(uint) {
        return fromUD60x18(toUD60x18(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedInterest(uint tokenId) public view returns(uint) { // Note: made this duplicate of accruedInterest() for testing
        return accruedInterest(_loans[tokenId]);
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(toUD60x18(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }

    function calculatePaymentPerSecond(uint principal, UD60x18 ratePerSecond, uint maxDurationSeconds) /*private*/ public pure returns(UD60x18 paymentPerSecond) {

        // Calculate x
        // - (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // - (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_MAX_UD60x18
        // - maxDurationMonths * monthSeconds <= log(MAX_UD60x18) / log(1 + ratePerSecond)
        // - maxDurationMonths <= (log(MAX_UD60x18) / log(1 + ratePerSecond)) / monthSeconds // Note: ratePerSecond depends on util (so solve for maxDurationMonths)
        // - maxDurationMonths <= log(MAX_UD60x18) / (monthSeconds * log(1 + ratePerSecond))
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(maxDurationSeconds);

        // principal * ratePerSecond * x <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** maxDurationSeconds <= MAX_UD60x18
        // principal * ratePerSecond * (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18
        // (1 + ratePerSecond) ** (maxDurationMonths * monthSeconds) <= MAX_UD60x18 / (principal * ratePerSecond)
        // maxDurationMonths * monthSeconds <= log_(1 + ratePerSecond)_(MAX_UD60x18 / (principal * ratePerSecond))
        // maxDurationMonths * monthSeconds <= log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)
        // maxDurationMonths <= (log(MAX_UD60x18 / (principal * ratePerSecond)) / log(1 + ratePerSecond)) / monthSeconds
        // maxDurationMonths <= log(MAX_UD60x18 / (principal * ratePerSecond)) / (monthSeconds * log(1 + ratePerSecond))
        
        // Calculate paymentPerSecond
        paymentPerSecond = toUD60x18(principal).mul(ratePerSecond).mul(x).div(x.sub(toUD60x18(1)));
    }

    function borrowerRatePerSecond() private view returns(UD60x18 ratePerSecond) {
        ratePerSecond = borrowerApr().div(toUD60x18(yearSeconds)); // Todo: improve precision
    }

    function borrowerApr() public view returns(UD60x18 apr) {
        
        // Get utilization
        UD60x18 _utilization = utilization();

        assert(_utilization.lte(toUD60x18(1))); // Note: utilization should never exceed 100%

        if (_utilization.lte(optimalUtilization)) {
            apr = m1.mul(_utilization).add(b1);

        } else if (_utilization.gt(optimalUtilization) && _utilization.lt(toUD60x18(1))) {
            SD59x18 x = intoSD59x18(m2.mul(_utilization));
            apr = intoUD60x18(x.add(b2()));

        } else if (_utilization.eq(toUD60x18(1))) {
            revert("no APR. can't start loan if utilization = 100%");
        }

        assert(apr.gt(toUD60x18(0)));
        assert(apr.lt(toUD60x18(1)));
    }

    function utilization() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(totalPrincipal == 0);
            return toUD60x18(0);
        }
        return toUD60x18(totalPrincipal).div(toUD60x18(totalDeposits));
    }

    function b2() private view returns(SD59x18) {
        SD59x18 x = intoSD59x18(m1).sub(intoSD59x18(m2));
        SD59x18 y = intoSD59x18(optimalUtilization).mul(x);
        return y.add(intoSD59x18(b1));
    }

    function defaulted(uint tokenId) private view returns(bool) {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(loan);

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

    // Other Views
    function principalCap(Loan memory loan, uint month) public pure returns(uint cap) {

        // Ensure month doesn't exceed loanMaxDurationMonths
        require(month <= loanMaxMonths(loan), "month must be <= loanMaxDurationMonths");

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = toSD59x18(int(elapsedSeconds)).sub(toSD59x18(int(loan.maxDurationSeconds))).sub(toSD59x18(1));

        // Calculate numerator
        SD59x18 z = toSD59x18(1).sub(SD59x18.wrap(int(UD60x18.unwrap(toUD60x18(1).add(loan.ratePerSecond)))).pow(negExponent));
        UD60x18 numerator = UD60x18.wrap(uint(SD59x18.unwrap(SD59x18.wrap(int(UD60x18.unwrap(loan.paymentPerSecond))).mul(z))));

        // Calculate cap
        cap = fromUD60x18(numerator.div(loan.ratePerSecond));
    }

    function status(uint tokenId) public view returns (Status) {

        Loan memory loan = _loans[tokenId];
        
        // If no borrower
        if (loan.borrower == address(0)) {
            return Status.None;

        // If borrower
        } else {
            
            // If default
            if (defaulted(tokenId)) {
                
                // Calculate timeSinceDefault
                uint timeSinceDefault = block.timestamp - defaultTime(loan);

                if (timeSinceDefault <= redemptionWindow) {
                    return Status.Default;
                } else {
                    return Status.Foreclosurable;
                }

            // If no default
            } else {
                return Status.Mortgage;
            }
        }
    }

    function availableLiquidity() /* private */ public view returns(uint) {
        return totalDeposits - totalPrincipal;
    }

    function lenderApy() public view returns(UD60x18) {
        if (totalDeposits == 0) {
            assert(maxTotalInterestOwed == 0);
            return toUD60x18(0);
        }
        return toUD60x18(maxTotalInterestOwed).div(toUD60x18(totalDeposits)); // Question: is this missing auto-compounding?
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function defaultTime(Loan memory loan) private view returns (uint _defaultTime) {

        uint completedMonths = loanCompletedMonths(loan);

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) {

            uint completedMonthPrincipalCap = principalCap(loan, i);
            uint prevCompletedMonthPrincipalCap = principalCap(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _defaultTime = loan.startTime + (i * monthSeconds);
            }
        }
    }
}