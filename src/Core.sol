// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Math.sol";
import "./ILoan.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

type PropertyId is uint;

contract Core is Math, ILoan {

    // Loan Storage
    mapping(PropertyId => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function loanEquity(PropertyId propertyId) public view returns (UD60x18 equity) {

        // Get Loan
        Loan memory loan = loans[propertyId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function deposit(uint usdc) external {

        // Pull LIQ from staker
        USDC.safeTransferFrom(msg.sender, address(this), usdc);

        // Add usdc to totalSupply
        totalSupply = totalSupply.add(toUD60x18(usdc));

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
        totalSupply = totalSupply.sub(toUD60x18(usdc));
        require(totalSupply.gte(totalDebt), "utilzation can't exceed 100%");
    }

    function borrow(PropertyId propertyId, uint propertyValue, uint principal, uint yearsCount) external {
        require(toUD60x18(principal).div(toUD60x18(propertyValue)).lte(maxLtv), "cannot exceed maxLtv");

        // change property nft state

        // Calculate monthlyRate
        UD60x18 monthlyRate = currentYearlyRate().div(toUD60x18(12));

        // Calculate monthsCount
        uint monthsCount = yearsCount * 12;

        // Store Loan
        loans[propertyId] = Loan({
            propertyValue: toUD60x18(propertyValue),
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: toUD60x18(principal),
            borrower: msg.sender
        });

        // Add principal to totalDebt
        totalDebt = totalDebt.add(toUD60x18(principal));
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(PropertyId propertyId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[propertyId];

        // Calculate accrued
        UD60x18 accrued = loan.monthlyRate.mul(loan.balance);
        require(toUD60x18(repayment).gte(accrued), "repayment must >= accrued interest"); // might change later due to multiple repayments within the month

        // Calculate balanceRepayment
        UD60x18 balanceRepayment = toUD60x18(repayment).sub(accrued);

        // Remove balanceRepayment from balance
        loan.balance = loan.balance.sub(balanceRepayment);

        // Remove balanceRepayment from totalDebt
        totalDebt = totalDebt.sub(balanceRepayment);

        // Add accrued to totalSupply
        totalSupply = totalSupply.add(accrued);

        // If loan fully repaid
        if (loan.balance.eq(ud(0))) {
            // transfer property nft to borrower
        }
    }
}
