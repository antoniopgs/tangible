// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

type PropertyId is uint;

contract Math3 {

    struct Loan {
        PRBMath.UD60x18 propertyValue;
        PRBMath.UD60x18 monthlyRate;
        PRBMath.UD60x18 monthlyPayment;
        PRBMath.UD60x18 balance;
    }

    IERC20 public USDC;
    IERC20 public tUSDC;

    // System Vars
    PRBMath.UD60x18 private totalDebt; // maybe rename to totalBorrowed?
    PRBMath.UD60x18 private totalSupply;
    PRBMath.UD60x18 public maxLtv;

    // Interest Rate Vars
    PRBMath.UD60x18 public optimalUtilization;
    PRBMath.UD60x18 public m1;
    PRBMath.UD60x18 public b1;
    PRBMath.UD60x18 public m2;

    // Loan Storage
    mapping(PropertyId => Loan) public loans;

    // Libs
    using PRBMathUD60x18Typed for PRBMath.UD60x18;
    using PRBMathUD60x18Typed for uint;
    using SafeERC20 for IERC20;

    constructor() {
        maxLtv = uint(50).fromUint().div(uint(100).fromUint()); // 0.5
    }

    function b2() private view returns (PRBMath.UD60x18 memory) {
        return optimalUtilization.mul(m1.sub(m2)).add(b1);
    }

    function utilization() public view returns (PRBMath.UD60x18 memory) {
        return totalDebt.div(totalSupply);
    }

    function currentYearlyRate() public view returns (PRBMath.UD60x18 memory) {

        // Get utilization
        PRBMath.UD60x18 memory _utilization = utilization();

        // If utilization <= optimalUtilization
        if (_utilization.value <= optimalUtilization.value) {
            return m1.mul(_utilization).add(b1);

        // If utilization > optimalUtilization
        } else {
            return m2.mul(_utilization).add(b2());
        }
    }

    function loanEquity(PropertyId propertyId) public view returns (PRBMath.UD60x18 memory equity) {

        // Get Loan
        Loan memory loan = loans[propertyId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function usdcToTusdcRatio() private view returns(PRBMath.UD60x18 memory) {
        
        // Get tusdcSupply
        uint tusdcSupply = tUSDC.totalSupply();

        if (tusdcSupply == 0 || totalSupply.value == 0) {
            return uint(1).fromUint();

        } else {
            return tusdcSupply.fromUint().div(totalSupply);
        }
    }

    function usdcToTusdc(uint usdc) private view returns(uint tusdc) {
        tusdc = usdc.fromUint().mul(usdcToTusdcRatio()).toUint();
    }

    function calculateMonthlyPayment(uint principal, PRBMath.UD60x18 memory monthlyRate, uint monthsCount) private pure returns(PRBMath.UD60x18 memory monthlyPayment) {

        // Calculate r
        PRBMath.UD60x18 memory r = uint(1).fromUint().div(uint(1).fromUint().add(monthlyRate));

        // Calculate monthlyPayment
        monthlyPayment = principal.fromUint().mul(uint(1).fromUint().sub(r).div(r.sub(r.powu(monthsCount + 1))));
    }

    function deposit(uint usdc) external {

        // Pull LIQ from staker
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Add usdc to totalSupply
        totalSupply = totalSupply.add(usdc.fromUint());

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Mint tusdc to depositor
        // tUSDC.mint(msg.sender, tusdc); // FIX LATER
    }

    function withdraw(uint usdc) external {

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Burn tusdc from withdrawer
        // tUSDC.burn(msg.sender, tusdc); // FIX LATER

        // Send LIQ to unstaker
        USDC.safeTransfer(msg.sender, usdc); // reentrancy possible?

        // Remove usdc from totalSupply
        totalSupply = totalSupply.sub(usdc.fromUint());
        require(totalSupply.value >= totalDebt.value, "utilzation can't exceed 100%");
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
}
