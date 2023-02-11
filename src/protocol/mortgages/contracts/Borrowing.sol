// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IBorrowing.sol";
import "./LoanTimeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Borrowing is IBorrowing, LoanTimeMath {

    // Libs
    using SafeERC20 for IERC20;
    
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

    function propertyEquity(string calldata propertyUri) external view returns (UD60x18 equity) {

        // Get Loan
        Loan memory loan = loans[propertyUri];

        // Calculate equity
        equity = loan.propertyValue.sub(loan.balance);
    }

    function foreclose(string calldata propertyUri) external {

        // Get loan
        Loan storage loan = loans[propertyUri];

        // Ensure borrower has defaulted
        require(state(loan) == State.Default);

        // Zero-out nextPaymentDeadline
        loan.nextPaymentDeadline = 0;
    }

    function foreclosurable(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline + (30 days * allowedDelayedPayments);
    }

    function state(Loan memory loan) internal view returns (State) {
        
        // If no borrower
        if (loan.borrower == address(0)) {
            return State.Null;

        // If borrower
        } else {
            
            // If not foreclosurable
            if (!foreclosurable(loan)) {
                
                // If positive payment deadline
                if (loan.nextPaymentDeadline > 0 ) {
                    return State.Mortgage;

                // If no payment deadline
                } else {
                    return State.Foreclosed;
                }

            // If foreclosurable
            } else {
                return State.Default;
            }
        }
    }
}
