// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
// import "./LoanTimeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./State.sol";
// import "@prb/math/UD60x18.sol";

// Note: later replace onlyOwner with a modifier with better upgradeabitlity
abstract contract Borrowing is IBorrowing/*, LoanTimeMath*//*, State, Ownable*/ {

    // Libs
    // using SafeERC20 for IERC20;

    // WHO should start loans?
    function startLoan(TokenId _tokenId, uint propertyValue, uint downPayment, address borrower) external /* onlyOwner */ {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure property has no associated loan
        require(state(loan) == State.Null, "property already has associated loan");

        // Calculate principal
        UD60x18 principal = propertyValue.sub(downPayment);

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
        loans[tokenId] = Loan({
            borrower: borrower,
            balance: principal,
            installment: installment,
            unpaidInterest: totalLoanCost.sub(principal),
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Pull downPayment from borrower/caller to pool
        USDC.safeTransferFrom(msg.sender, address(pool), fromUD60x18(downPayment));

        // Send propertyValue from pool to seller
        USDC.safeTransferFrom(address(pool), seller, fromUD60x18(propertyValue));

        // Emit event
        emit NewLoan(tokenId, propertyValue, principal, borrower, seller, block.timestamp);
    }
    
    function payLoan(TokenId _tokenId) external {

        // Load loan
        Loan storage loan = loans[tokenId];

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
        emit LoanPayment(tokenId, msg.sender, block.timestamp, loanPaid);
    }

    function calculateInstallment(UD60x18 principal) internal view returns(UD60x18 installment) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicBorrowerRate).pow(installmentCount);
        
        // Calculate installment
        installment = principal.mul(periodicBorrowerRate).mul(x).div(x.sub(toUD60x18(1)));
    }
}
