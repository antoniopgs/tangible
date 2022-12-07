// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

type PropertyId is uint;

contract Math3 {

    struct Loan {
        uint monthlyRate;
        uint monthlyPayment;
        uint balance;
        uint equity;
    }

    mapping(PropertyId => Loan) public loans;
    uint maxLtv = 50 / 100;

    function calculateMonthlyPayment(uint principal, uint monthlyRate, uint monthsCount) private pure returns(uint monthlyPayment) {
        uint r = 1 / (1 + monthlyRate);
        monthlyPayment = principal * ((1 - r) / (r - r ** (monthsCount + 1)));
    }

    function borrow(PropertyId propertyId, uint propertyValue, uint principal, uint yearlyRate, uint yearsCount) external {
        require(principal / propertyValue <= maxLtv, "cannot exceed maxLtv");

        // Calculate monthlyRate
        uint monthlyRate = yearlyRate / 12;

        // Calculate monthsCount
        uint monthsCount = yearsCount * 12;

        // Store Loan
        loans[propertyId] = Loan({
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: principal,
            equity: propertyValue - principal
        });
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(PropertyId propertyId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[propertyId];

        // Calculate accruedInterest
        uint accruedInterest = loan.monthlyRate * loan.balance;
        
        // Add accruedInterest to loanBalance
        loan.balance += accruedInterest;

        // Decrease loan.balance by repayment
        loan.balance -= repayment;

        // Update loan.equity
        loan.equity += repayment - accruedInterest;
    }
}