// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "https://github.com/PaulRBerg/prb-math/blob/main/src/UD60x18.sol";

contract BorrowingV2Monthly {

    // Structs
    struct Loan {
        UD60x18 monthlyRate;
        UD60x18 unpaidPrincipal;
        UD60x18 unpaidInterest;
        uint nextPaymentDeadline;
    }

    // Borrowing terms
    uint private constant loanYears = 5; // each year will have 360 days (30 days * 12)

    // Main storage
    mapping(uint => Loan) public loans;

    // Pool vars
    UD60x18 totalPrincipal;
    UD60x18 totalDeposits;
    UD60x18 totalInterestOwed;

    function utilization() public view returns (UD60x18) {
        return totalPrincipal.div(totalDeposits);
    }

    function lenderApy() external view returns(UD60x18) { // Note: probably need to convert from 360 to 365 days
        return totalInterestOwed.div(totalDeposits);
    }

    function borrowerApr(UD60x18 /* utilization */) private /* view */ pure returns (UD60x18) {
        return toUD60x18(5).div(toUD60x18(100)); // 5%
    }

    function monthlyRate() private view returns(UD60x18) {
        return borrowerApr(utilization()).div(toUD60x18(12));
    }

    // Functions
    function startLoan(uint tokenId, uint principal) external { // Note: principal should be uint (not UD60x18)

        // Calculate monthlyRate
        UD60x18 _monthlyRate = monthlyRate();

        // Calculate loanMonths
        uint loanMonths = loanYears * 12;

        // Calculate monthlyPayment
        UD60x18 monthlyPayment = calculateMonthlyPayment(toUD60x18(principal), _monthlyRate, loanMonths);

        // Calculate loanCost
        UD60x18 loanCost = monthlyPayment.mul(toUD60x18(loanMonths));

        // Calculate loanMaxUnpaidInterest
        UD60x18 unpaidInterest = loanCost.sub(toUD60x18(principal));

        // Store Loan
        loans[tokenId] = Loan({
            monthlyRate: _monthlyRate,
            unpaidPrincipal: toUD60x18(principal),
            unpaidInterest: unpaidInterest,
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Update pool
        totalPrincipal = totalPrincipal.add(toUD60x18(principal));
        totalInterestOwed = totalInterestOwed.add(unpaidInterest);
    }
    
    function payLoan(uint tokenId, uint payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Calculate interest
        UD60x18 interest = loan.monthlyRate.mul(loan.unpaidPrincipal);

        // Calculate repayment
        UD60x18 repayment = toUD60x18(payment).sub(interest);

        // Update loan
        loan.unpaidPrincipal = loan.unpaidPrincipal.sub(repayment);
        loan.unpaidInterest = loan.unpaidInterest.sub(interest);
        loan.nextPaymentDeadline += 30 days;

        // Update pool
        totalPrincipal = totalPrincipal.sub(repayment);
        totalDeposits = totalDeposits.add(interest);
        totalInterestOwed = totalInterestOwed.sub(interest);
    }

    function calculateMonthlyPayment(UD60x18 principal, UD60x18 _monthlyRate, uint loanMonths) private pure returns(UD60x18) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(_monthlyRate).powu(loanMonths);
        
        // Calculate avgPaymentPerSecond
        return principal.mul(_monthlyRate).mul(x).div(x.sub(toUD60x18(1)));
    }

    function defaulted(Loan memory loan) private view returns(bool) {
        
    }
}