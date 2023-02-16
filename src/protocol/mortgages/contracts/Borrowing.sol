// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IBorrowing.sol";
import "./LoanTimeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./State.sol";

// Note: later replace onlyOwner with a modifier with better upgradeabitlity
abstract contract Borrowing is IBorrowing, LoanTimeMath, State, Ownable {

    // Libs
    using SafeERC20 for IERC20;

    // WHO should start loans?
    function startLoan(string calldata propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) external onlyOwner {

        // Get Loan
        Loan storage loan = loans[propertyUri];

        // Ensure property has no associated loan
        require(state(loan) == State.Null, "property already has associated loan");

        // Calculate bid ltv
        UD60x18 ltv = principal.div(propertyValue);

        // Ensure ltv <= maxLtv
        require(ltv.lte(maxLtv), "ltv can't exceeed maxLtv");

        // Add principal to totalBorrowed
        totalBorrowed = totalBorrowed.add(principal);
        
        // Ensure utilization <= utilizationCap
        require(utilization().lte(utilizationCap), "utilization can't exceed utilizationCap");

        // Calculate installment
        UD60x18 installment = calculateInstallment(principal);

        // Calculate totalLoanCost
        UD60x18 totalLoanCost = installment.mul(installmentCount);

        // Store Loan
        loans[propertyUri] = Loan({
            propertyUri: propertyUri,
            borrower: borrower,
            balance: principal,
            installment: installment,
            unpaidInterest: totalLoanCost.sub(principal),
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Pull principal from borrower/caller to protocol
        USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(principal)); // RETHINK THIS

        // Send propertyValue from protocol to seller
        USDC.safeTransferFrom(address(this), seller, fromUD60x18(propertyValue)); // RETHINK THIS

        // Emit event
        emit NewLoan(propertyUri, propertyValue, principal, borrower, seller, block.timestamp);
    }
    
    function payLoan(string calldata propertyUri) external {

        // Load loan
        Loan storage loan = loans[propertyUri];

        require(msg.sender == loan.borrower, "only borrower can pay his loan");

        // Ensure property has active mortgage
        require(state(loan) == State.Mortgage, "property has no active mortgage"); // CAN BORROWERS ALSO PAY LOAN IF STATE == DEFAULTED?

        // Pull installment from borrower
        USDC.safeTransferFrom(msg.sender, address(this), fromUD60x18(loan.installment));

        // Calculate interest
        UD60x18 interest = periodicBorrowerRate.mul(loan.balance);

        // Calculate repayment
        UD60x18 repayment = loan.installment.sub(interest);

        // Remove repayment from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(repayment);
        totalBorrowed = totalBorrowed.sub(repayment);

        // Add interest to deposits
        totalDeposits = totalDeposits.add(interest);

        // Remove interest from loan.unpaidInterest
        loan.unpaidInterest = loan.unpaidInterest.sub(interest);

        // If loan completely paid off
        bool loanPaid = loan.balance.eq(toUD60x18(0));
        if (loanPaid) {

            // Reset loan state to Null (so it can re-enter system later)
            loan.borrower = address(0);

        // If more payments are needed to pay off loan
        } else {

            // Update loan.nextPaymentDeadline
            loan.nextPaymentDeadline += 30 days;
        }

        // Emit event
        emit LoanPayment(propertyUri, msg.sender, block.timestamp, loanPaid);
    }
}
