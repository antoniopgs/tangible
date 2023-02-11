// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IBorrowing.sol";
import "./LoanTimeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Borrowing is IBorrowing, LoanTimeMath {

    // Loan Storage
    mapping(string => Loan) public loans;

    // Libs
    using SafeERC20 for IERC20;

    function propertyEquity(string calldata propertyUri) external view returns (UD60x18 equity) {

        // Get Loan
        Loan memory loan = loans[propertyUri];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }
    
    // CAN ANYONE START LOAN? IT PROBABLY SHOULD BE GETTING QUEUED UP FIRST
    function startLoan(string calldata propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) public { // available to keepers

        // Calculate bid ltv
        UD60x18 ltv = principal.div(propertyValue);

        // Ensure ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv can't exceeed maxLtv");

        // Collateralize NFT

        // Send principal from protocol to seller
        USDC.safeTransferFrom(address(this), seller, fromUD60x18(principal));

        // change property nft state

        // Store Loan
        loans[propertyUri] = Loan({
            borrower: borrower,
            propertyValue: propertyValue,
            monthlyPayment: calculateMonthlyPayment(principal),
            balance: principal,
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Add principal to totalBorrowed
        totalBorrowed = totalBorrowed.add(principal);
        require(utilization().lte(utilizationCap), "utilization can't exceed utilizationCap");
    }
    
    function payLoan(string calldata propertyUri) external {

        // Load loan
        Loan storage loan = loans[propertyUri];

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
    }
}
