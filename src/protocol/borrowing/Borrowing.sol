// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IBorrowing.sol";
import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interest/IInterest.sol";

contract Borrowing is IBorrowing, State {

    // Libs
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    function adminStartLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 downPayment, address borrower) external onlyOwner {
        startLoan(tokenId, propertyValue, downPayment, borrower);
    }

    function acceptBidStartLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 downPayment, address borrower) external {
        require(msg.sender == address(this), "unauthorized"); // Note: msg.sender must be address(this) because this will be called via delegatecall
        startLoan(tokenId, propertyValue, downPayment, borrower);
    }

    function startLoan(TokenId tokenId, UD60x18 propertyValue, UD60x18 downPayment, address borrower) private {

        // Get Loan
        Loan storage loan = loans[tokenId];

        // Ensure property has no associated loan
        require(state(loan) == State.None, "property already has associated loan");

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

        // Calculate & decode yearlyBorrowerRate
        (bool success, bytes memory data) = logicTargets[IInterest.calculateYearlyBorrowerRate.selector].delegatecall(
            abi.encodeCall(
                IInterest.calculateYearlyBorrowerRate,
                (utilization())
            )
        );
        require(success, "calculateYearlyBorrowerRate delegateCall failed");
        UD60x18 yearlyBorrowerRate = abi.decode(data, (UD60x18));

        // Calculate periodicBorrowerRate
        UD60x18 periodicBorrowerRate = yearlyBorrowerRate.div(periodsPerYear);

        // Calculate installment
        UD60x18 installment = calculateInstallment(periodicBorrowerRate, principal);

        // Calculate totalLoanCost
        UD60x18 totalLoanCost = installment.mul(installmentCount);

        // Store Loan
        loans[tokenId] = Loan({
            borrower: borrower,
            balance: principal,
            periodicBorrowerRate: periodicBorrowerRate,
            installment: installment,
            unpaidInterest: totalLoanCost.sub(principal),
            nextPaymentDeadline: block.timestamp + 30 days
        });

        // Add tokenId to loansTokenIds
        loansTokenIds.add(TokenId.unwrap(tokenId));

        // Pull downPayment from borrower
        USDC.safeTransferFrom(borrower, address(this), fromUD60x18(downPayment));

        // Emit event
        emit NewLoan(tokenId, propertyValue, principal, borrower, block.timestamp);
    }
    
    function payLoan(TokenId tokenId) external {

        // Load loan
        Loan storage loan = loans[tokenId];

        // Ensure caller is borrower
        require(msg.sender == loan.borrower, "only borrower can pay his loan");

        // Ensure property has active mortgage
        require(state(loan) == State.Mortgage, "property has no active mortgage");

        // Pull installment from borrower
        USDC.safeTransferFrom(loan.borrower, address(this), fromUD60x18(loan.installment));

        // Calculate interest
        UD60x18 interest = loan.periodicBorrowerRate.mul(loan.balance);

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

            // Send Nft
            sendNft(loan, loan.borrower, TokenId.unwrap(tokenId));

        // If more payments are needed to pay off loan
        } else {

            // Update loan.nextPaymentDeadline
            loan.nextPaymentDeadline += 30 days;
        }

        // Emit event
        emit LoanPayment(tokenId, loan.borrower, block.timestamp, loanPaid);
    }

    function calculateInstallment(UD60x18 periodicBorrowerRate, UD60x18 principal) private view returns(UD60x18 installment) {

        // Calculate x
        UD60x18 x = toUD60x18(1).add(periodicBorrowerRate).pow(installmentCount);
        
        // Calculate installment
        installment = principal.mul(periodicBorrowerRate).mul(x).div(x.sub(toUD60x18(1)));
    }

    function redeemLoan(TokenId tokenId) external {
        
        // Get loan
        Loan storage loan = loans[tokenId];

        // Ensure caller is borrower
        require(msg.sender == loan.borrower, "only borrower can pay his loan");

        // Ensure borrower has defaulted
        require(state(loan) == State.Default, "no default");

        // Ensure redemptionWindow has passed
        require(block.timestamp >= loan.nextPaymentDeadline + redemptionWindow);

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.balance.add(loan.unpaidInterest); // should redeemer pay all the interest? or only the interest until redemption time?

        // Redeem (pull defaulter's entire debt)
        USDC.safeTransferFrom(loan.borrower, address(this), fromUD60x18(defaulterDebt));

        // Remove loan.balance from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(loan.balance);
        totalBorrowed = totalBorrowed.sub(loan.balance);

        // Add unpaidInterest to totalDeposits
        totalDeposits = totalDeposits.add(loan.unpaidInterest);

        // Send Nft to borrower
        sendNft(loan, loan.borrower, TokenId.unwrap(tokenId));
    }
}
