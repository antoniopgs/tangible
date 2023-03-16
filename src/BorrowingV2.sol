// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract BorrowingV2 {

    // Borrowing terms
    uint public loanMaxYears = 5;

    // Structs
    struct Loan {
        UD60x18 ratePerSecond;
        UD60x18 unpaidPrincipal;
        UD60x18 maxUnpaidInterest;
        uint lastPaymentTime;
    }

    // Pool vars
    UD60x18 totalPrincipal;
    UD60x18 totalDeposits;
    UD60x18 totalInterestOwed;

    // Loan storage
    mapping(uint => Loan) public loans;

    // Functions
    function utilization() public view returns (UD60x18) {
        return totalPrincipal.div(totalDeposits);
    }

    function lenderApy() external view returns(UD60x18) {
        return totalInterestOwed.div(totalDeposits);
    }

    function timeDeltaSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }

    function borrowerApr(UD60x18 /* utilization */) public /* view */ pure returns (UD60x18) {
        return toUD60x18(5).div(toUD60x18(100)); // 5%
    }

    function borrowerRatePerSecond() private view returns(UD60x18) {
        return borrowerApr(utilization()).div(toUD60x18(365 days));
    }

    function startLoan(uint tokenId, uint principal) external { // Note: principal should be uint (not UD60x18)

        // Calculate loanRatePerSecond
        UD60x18 loanRatePerSecond = borrowerRatePerSecond();

        // Calculate loanMaxSeconds
        uint loanMaxSeconds = loanMaxYears * 365 days;

        // Calculate avgPaymentPerSecond
        UD60x18 _avgPaymentPerSecond = avgPaymentPerSecond(toUD60x18(principal), loanRatePerSecond, loanMaxSeconds);

        // Calculate loanMaxCost
        UD60x18 loanMaxCost = _avgPaymentPerSecond.mul(toUD60x18(loanMaxSeconds));

        // Calculate loanMaxUnpaidInterest
        UD60x18 loanMaxUnpaidInterest = loanMaxCost.sub(toUD60x18(principal));

        // Store Loan
        loans[tokenId] = Loan({
            ratePerSecond: borrowerRatePerSecond(),
            unpaidPrincipal: toUD60x18(principal),
            maxUnpaidInterest: loanMaxUnpaidInterest,
            lastPaymentTime: block.timestamp // Note: so loan starts accruing from now (not a payment)
        });

        // Update pool
        totalPrincipal = totalPrincipal.add(toUD60x18(principal));
        totalInterestOwed = totalInterestOwed.add(loanMaxUnpaidInterest);
    }
    
    function payLoan(uint tokenId, uint payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Calculate interest
        UD60x18 interest = loan.ratePerSecond.mul(toUD60x18(timeDeltaSinceLastPayment(loan)));

        // Calculate repayment
        UD60x18 repayment = toUD60x18(payment).sub(interest);

        // Update loan
        loan.unpaidPrincipal = loan.unpaidPrincipal.sub(repayment);
        loan.maxUnpaidInterest = loan.maxUnpaidInterest.sub(interest);

        // Update pool
        totalPrincipal = totalPrincipal.sub(repayment);
        totalDeposits = totalDeposits.add(interest);
        totalInterestOwed = totalInterestOwed.sub(interest);
    }

    function avgPaymentPerSecond(UD60x18 principal, UD60x18 ratePerSecond, uint loanMaxSeconds) private pure returns(UD60x18) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(ratePerSecond).powu(loanMaxSeconds);
        
        // Calculate avgPaymentPerSecond
        return principal.mul(ratePerSecond).mul(x).div(x.sub(toUD60x18(1)));
    }

    // If borrower paid avgPaymentPerSecond every second, each payment's interest would be: ratePerSecond * 1s = ratePerSecond
    // So each payment's repayment would be: avgPaymentPerSecond - ratePerSecond
    // So each second:
    //  - loan.maxUnpaidInterest -= ratePerSecond
    //  - loan.unpaidPrincipal -= avgPaymentPerSecond - ratePerSecond
    // So 30 days later:
    // - loan.maxUnpaidInterest -= 30 days(ratePerSecond);
    // - loan.unpaidPrincipal -= 30 days(avgPaymentPerSecond - ratePerSecond);
    function defaulted(Loan memory loan) private view returns(bool) {
        timeDeltaSinceLastPayment(loan) > 30 days && ??? < loan.nextDeadlineMax???;
    }
}
