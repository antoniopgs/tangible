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

    // System Vars
    PRBMath.UD60x18 private totalDebt; // maybe rename to totalBorrowed?
    PRBMath.UD60x18 private totalSupply;
    PRBMath.UD60x18 public maxLtv;

    // Interest Rate Vars
    PRBMath.UD60x18 public optimalUtilization;
    PRBMath.UD60x18 public baseRate;
    PRBMath.UD60x18 public slope1;
    PRBMath.UD60x18 public slope2;

    // Loan Storage
    mapping(PropertyId => Loan) public loans;

    // Libs
    using PRBMathUD60x18Typed for PRBMath.UD60x18;
    using PRBMathUD60x18Typed for uint;

    constructor() {
        maxLtv = uint(50).fromUint().div(uint(100).fromUint()); // 0.5
    }

    function utilization() public view returns (PRBMath.UD60x18 memory) {
        return totalDebt.div(totalSupply);
    }

    function currentYearlyRate() public view returns (PRBMath.UD60x18 memory) {

        // Get utilization
        PRBMath.UD60x18 memory _utilization = utilization();

        // If utilization <= optimalUtilization
        if (_utilization.value <= optimalUtilization.value) {
            return baseRate.add(_utilization.div(optimalUtilization).mul(slope1));

        // If utilization > optimalUtilization
        } else {
            return baseRate.add(slope1).add(_utilization.sub(optimalUtilization).div(uint(1).fromUint().sub(optimalUtilization)).mul(slope2));
        }
    }

    function loanEquity(PropertyId propertyId) public view returns (PRBMath.UD60x18 memory equity) {

        // Get Loan
        Loan memory loan = loans[propertyId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function calculateMonthlyPayment(uint principal, PRBMath.UD60x18 memory monthlyRate, uint monthsCount) private pure returns(PRBMath.UD60x18 memory monthlyPayment) {

        // Calculate r
        PRBMath.UD60x18 memory r = uint(1).fromUint().div(uint(1).fromUint().add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.fromUint().mul(uint(1).fromUint().sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }

    function borrow(PropertyId propertyId, uint propertyValue, uint principal, uint yearsCount) external {
        require(principal.fromUint().div(propertyValue.fromUint()).value <= maxLtv.value, "cannot exceed maxLtv");

        // Calculate monthlyRate
        PRBMath.UD60x18 memory monthlyRate = currentYearlyRate().div(uint(12).fromUint());

        // Calculate monthsCount
        uint monthsCount = yearsCount * 12;

        // Store Loan
        loans[propertyId] = Loan({
            propertyValue: propertyValue.fromUint(),
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: principal.fromUint()
        });

        // Add principal to totalDebt
        totalDebt = totalDebt.add(principal.fromUint());
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(PropertyId propertyId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[propertyId];

        // Calculate accrued
        PRBMath.UD60x18 memory accrued = loan.monthlyRate.mul(loan.balance);
        require(repayment.fromUint().value >= accrued.value, "repayment must >= accrued interest"); // might change later due to multiple repayments within the month

        // Calculate balanceRepayment
        PRBMath.UD60x18 memory balanceRepayment = repayment.fromUint().sub(accrued);

        // Remove balanceRepayment from balance
        loan.balance = loan.balance.sub(balanceRepayment);

        // Remove balanceRepayment from totalDebt
        totalDebt = totalDebt.sub(balanceRepayment);

        // Add accrued to totalSupply
        totalSupply = totalSupply.add(accrued);
    }

    function deposit(uint _deposit) external {
        totalSupply = totalSupply.add(_deposit.fromUint());
    }

    function withdraw(uint _withdrawal) external {
        totalSupply = totalSupply.sub(_withdrawal.fromUint());
        require(totalSupply.value >= totalDebt.value, "utilzation can't exceed 100%");
    }
}
