// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Math.sol";
import "./ILoan.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Lending is Math, ILoan {

    // Loan Term vars
    UD60x18 public maxLtv = toUD60x18(50).div(toUD60x18(100)); // 0.5
    uint mortgageYears = 30;

    // Loan Storage
    mapping(uint => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function loanEquity(uint tokenId) public view returns (UD60x18 equity) {

        // Get Loan
        Loan memory loan = loans[tokenId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function startLoan(uint tokenId, uint propertyValue, uint principal, address borrower, address seller) internal {
        require(toUD60x18(principal).div(toUD60x18(propertyValue)).lte(maxLtv), "cannot exceed maxLtv");

        // Collateralize NFT

        // Send principal from protocol to seller
        USDC.safeTransferFrom(address(this), seller, principal);

        // change property nft state

        // Calculate monthlyRate
        UD60x18 monthlyRate = interest.currentYearlyRate(utilization()).div(toUD60x18(12));

        // Calculate monthsCount
        uint monthsCount = mortgageYears * 12;

        // Store Loan
        loans[tokenId] = Loan({
            propertyValue: toUD60x18(propertyValue),
            monthlyRate: monthlyRate,
            monthlyPayment: calculateMonthlyPayment(principal, monthlyRate, monthsCount),
            balance: toUD60x18(principal),
            borrower: borrower
        });

        // Add principal to totalDebt
        totalDebt = totalDebt.add(toUD60x18(principal));
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(uint tokenId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

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
