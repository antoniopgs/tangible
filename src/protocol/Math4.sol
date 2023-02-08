// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract Math4 {

    struct Loan {
        UD60x18 balance;
        UD60x18 monthlyRate;
        UD60x18 monthlyPayment;
        uint nextPaymentDeadline;
    }

    UD60x18 outstandingDebt;
    UD60x18 interestOwed;
    UD60x18 deposits;
    
    mapping(uint => Loan) public loans;

    function payLoan(uint tokenId, UD60x18 payment) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Ensure payment >= loan.monthlyPayment
        require(payment.gte(loan.monthlyPayment), "payment must be >= monthlyPayment");

        // Calculate interest
        UD60x18 interest = loan.monthlyRate.mul(loan.balance);

        // Calculate repayment
        UD60x18 repayment = payment.sub(interest);

        // Remove repayment from loan.balance & outstandingDebt
        loan.balance = loan.balance.sub(repayment);
        outstandingDebt = outstandingDebt.sub(repayment);

        // Add interest to deposits
        deposits = deposits.add(interest);

        // interestOwed = interestOwed - prevInterest + newInterest
        // interestOwed = interestOwed - (rate * loan.prevBalance) + (rate * loan.newBalance)
        // interestOwed = interestOwed - rate(loan.prevBalance - loan.newBalance)
        // interestOwed = interestOwed - rate(repayment)
        interestOwed = interestOwed.sub(loan.monthlyRate.mul(repayment)); // don't forget to increase interestOwed in startLoan()

        // Update loan.nextPaymentDeadline
        loan.nextPaymentDeadline += 30 days;
    }
}