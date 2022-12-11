// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/ILending.sol";
import "./Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Lending is ILending, Math {

    // Loan Term vars // MAYBE MOVE THESE VARS TO THE INTEREST CONTRACT?
    UD60x18 public ltv = toUD60x18(50).div(toUD60x18(100)); // 0.5
    uint public mortgageYears = 30;

    // Loan Storage
    mapping(uint => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function loanEquity(uint tokenId) external view returns (UD60x18 equity) {

        // Get Loan
        Loan memory loan = loans[tokenId];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function startLoan(uint tokenId, uint propertyValue, address borrower, address seller) internal {

        // Calculate principal
        UD60x18 principal = ltv.mul(toUD60x18(propertyValue));

        // Collateralize NFT

        // Send principal from protocol to seller
        USDC.safeTransferFrom(address(this), seller, fromUD60x18(principal));

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
            balance: principal,
            borrower: borrower
        });

        // Add principal to totalDebt
        totalDebt = totalDebt.add(principal);
    }
    
    // do we allow multiple repayments within the month? if so, what updates are needed to the math?
    function repay(uint tokenId, uint repayment) external {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // UD60x18 closingCosts = (loan.monthlyRate * timeDelta) * loan.balance;

        // Calculate accruedxw
        UD60x18 accrued = loan.monthlyRate.mul(loan.balance); // NEED TO FIX THIS // WAIT, OR IS THIS ALREADY ANTICIPATING THE NEXT MONTH?
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
