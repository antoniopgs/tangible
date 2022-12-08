// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Math.sol";
import "./ILoan.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

type PropertyId is uint;

contract Core is Math, ILoan {

    // Loan Storage
    mapping(PropertyId => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function loanEquity(PropertyId propertyId) public view returns (UD60x18  equity) {

        // Get Loan
        Loan memory loan = loans[propertyId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function deposit(uint usdc) external {

        // Pull LIQ from staker
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Add usdc to totalSupply
        totalSupply = totalSupply.add(usdc.fromUint());

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Mint tusdc to depositor
        tUSDC.mint(msg.sender, tusdc);
    }

    function withdraw(uint usdc) external {

        // Calculate tusdc
        uint tusdc = usdcToTusdc(usdc);

        // Burn tusdc from withdrawer/msg.sender
        tUSDC.burn(tusdc, "");

        // Send LIQ to unstaker
        USDC.safeTransfer(msg.sender, usdc); // reentrancy possible?

        // Remove usdc from totalSupply
        totalSupply = totalSupply.sub(usdc.fromUint());
        require(totalSupply.value >= totalDebt.value, "utilzation can't exceed 100%");
    }

    function borrow(PropertyId propertyId, uint propertyValue, uint principal, uint yearsCount) external {
        require(principal.fromUint().div(propertyValue.fromUint()).value <= maxLtv.value, "cannot exceed maxLtv");

        // change property nft state

        // Calculate monthlyRate
        UD60x18  monthlyRate = currentYearlyRate().div(uint(12).fromUint());

        // Calculate monthsCount
        uint monthsCount = yearsCount * 12;

        // Store Loan
        loans[propertyId] = Loan({
            propertyValue: propertyValue.fromUint(),
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: principal.fromUint(),
            borrower: msg.sender
        });

        // Add principal to totalDebt
        totalDebt = totalDebt.add(principal.fromUint());
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(PropertyId propertyId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[propertyId];

        // Calculate accrued
        UD60x18  accrued = loan.monthlyRate.mul(loan.balance);
        require(repayment.fromUint().value >= accrued.value, "repayment must >= accrued interest"); // might change later due to multiple repayments within the month

        // Calculate balanceRepayment
        UD60x18  balanceRepayment = repayment.fromUint().sub(accrued);

        // Remove balanceRepayment from balance
        loan.balance = loan.balance.sub(balanceRepayment);

        // Remove balanceRepayment from totalDebt
        totalDebt = totalDebt.sub(balanceRepayment);

        // Add accrued to totalSupply
        totalSupply = totalSupply.add(accrued);

        // If loan fully repaid
        if (loan.balance.value == 0) {
            // transfer property nft to borrower
        }
    }
}
