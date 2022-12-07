// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";

type PropertyId is uint;

contract Math3 {

    struct Loan {
        PRBMath.UD60x18 propertyValue;
        PRBMath.UD60x18 monthlyRate;
        PRBMath.UD60x18 monthlyPayment;
        PRBMath.UD60x18 balance;
    }

    using PRBMathUD60x18Typed for PRBMath.UD60x18;
    using PRBMathUD60x18Typed for uint;

    mapping(PropertyId => Loan) public loans;
    PRBMath.UD60x18 public maxLtv = uint(50).fromUint().div(uint(100).fromUint()); // 0.5

    function calculateMonthlyPayment(
        uint principal,
        PRBMath.UD60x18 memory monthlyRate,
        uint monthsCount
    ) private pure returns(PRBMath.UD60x18 memory monthlyPayment) {

        // Calculate r
        PRBMath.UD60x18 memory r = uint(1).fromUint().div(uint(1).fromUint().add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.fromUint().mul(uint(1).fromUint().sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }

    function borrow(PropertyId propertyId, uint propertyValue, uint principal, PRBMath.UD60x18 calldata yearlyRate, uint yearsCount) external {
        require(principal.fromUint().div(propertyValue.fromUint()).value <= maxLtv.value, "cannot exceed maxLtv");

        // Calculate monthlyRate
        PRBMath.UD60x18 memory monthlyRate = yearlyRate.div(uint(12).fromUint());

        // Calculate monthsCount
        uint monthsCount = yearsCount * 12;

        // Store Loan
        loans[propertyId] = Loan({
            propertyValue: propertyValue.fromUint(),
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: principal.fromUint()
        });
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(PropertyId propertyId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[propertyId];

        // Calculate accrued
        PRBMath.UD60x18 memory accrued = loan.monthlyRate.mul(loan.balance);
        require(repayment.fromUint().value >= accrued.value, "repayment must >= accrued interest"); // might change later due to multiple repayments within the month

        // Decrease balance by repayment - accrued
        loan.balance = loan.balance.sub(repayment.fromUint().sub(accrued));
    }

    function loanEquity(PropertyId propertyId) public view returns (PRBMath.UD60x18 memory equity) {

        // Get Loan
        Loan memory loan = loans[propertyId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }
}
