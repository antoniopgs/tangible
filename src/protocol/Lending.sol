// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/ILending.sol";
import "./Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Lending is ILending, Math {

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

    function startLoan(uint tokenId, uint propertyValue, address borrower, address seller) public { // available to keepers

        // Calculate principal
        UD60x18 principal = ltv.mul(toUD60x18(propertyValue));

        // Collateralize NFT

        // Send principal from protocol to seller
        USDC.safeTransferFrom(address(this), seller, fromUD60x18(principal));

        // change property nft state

        // Store Loan
        loans[tokenId] = Loan({
            propertyValue: toUD60x18(propertyValue),
            monthlyPayment: calculateMonthlyPayment(principal),
            balance: principal,
            borrower: borrower,
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Add principal to totalBorrowed
        totalBorrowed = totalBorrowed.add(principal);
    }
    
    function payLoan(uint tokenId) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Pull monthlyPayment from borrower
        USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(loan.monthlyPayment));

        // Calculate interest
        UD60x18 interest = monthlyBorrowerRate.mul(loan.balance);

        // Calculate repayment
        UD60x18 repayment = loan.monthlyPayment.sub(interest);

        // Remove repayment from loan.balance & outstandingDebt
        loan.balance = loan.balance.sub(repayment);
        totalBorrowed = totalBorrowed.sub(repayment);

        // Add interest to deposits
        totalDeposits = totalDeposits.add(interest);

        // Update loan.nextPaymentDeadline
        loan.nextPaymentDeadline += 30 days;

        // If loan fully repaid
        if (loan.balance.eq(ud(0))) { // maybe just do pull mechanism instead?
            // transfer property nft to borrower
        }
    }
}
