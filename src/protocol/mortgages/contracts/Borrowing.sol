// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../interfaces/IBorrowing.sol";
import "./LoanTimeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Borrowing is IBorrowing, LoanTimeMath, Ownable {

    // Libs
    using SafeERC20 for IERC20;

    // WHO should start loans?
    function startLoan(string calldata propertyUri, UD60x18 propertyValue, UD60x18 principal, address borrower, address seller) external {

        // Get Loan
        Loan storage loan = loans[propertyUri];

        // Ensure property has no associated loan
        require(state(loan) == State.Null, "property already has associated loan");

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

        // Ensure property has active mortgage
        require(state(loan) == State.Mortgage, "property has no active mortgage"); // CAN BORROWERS ALSO PAY LOAN IF STATE == DEFAULTED?

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

    function foreclose(string calldata propertyUri) external {

        // Get loan
        Loan storage loan = loans[propertyUri];

        // Ensure borrower has defaulted
        require(state(loan) == State.Default, "no default");

        // Zero-out nextPaymentDeadline
        loan.nextPaymentDeadline = 0;
    }

    function completeForeclosure(string calldata propertyUri, UD60x18 salePrice) external onlyOwner {

        // Get Loan
        Loan storage loan = loans[propertyUri];

        // Ensure property has been foreclosed
        require(state(loan) == State.Foreclosed, "no foreclosure");

        // Calculate defaulterDebt
        uint foreclosureDelay = block.timestamp - loan.lastPayment;
        UD60x18 foreclosureDelayMonths = toUD60x18(foreclosureDelay).div(toUD60x18(30 days));
        UD60x18 foreclosureAccrued = loan.monthlyPayment.mul(forecosureDelayMonths); // DOUBLE CHECK THIS
        UD60x18 defaulterDebt = loan.balance.add(foreclosureAccrued);

        // Pay defaulterDebt to lenders
        // remove repayment
        totalDeposits = totalDeposits.add(defaulterDebt);

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = salePrice.sub(defaulterDebt);

        // Send defaulterEquity to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, defaulterEquity);

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
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
