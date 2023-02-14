// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Borrowing.sol";

abstract contract Foreclosures is Borrowing {

    // Libs
    using SafeERC20 for IERC20;

    function chainlinkForeclose(string calldata propertyUri) external {
        Loan memory loan = loans[propertyUri];

        // Ensure loan is foreclosurable
        require(state(loan) == State.Default, "loan not foreclosurable");
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

        // Remove loan.balance from loan.balance & totalBorrowed
        loan.balance = loan.balance.sub(loan.balance);
        totalBorrowed = totalBorrowed.sub(loan.balance);

        // Add unpaidInterest to totalDeposits
        totalDeposits = totalDeposits.add(loan.unpaidInterest);

        // Calculate defaulterDebt
        UD60x18 defaulterDebt = loan.balance.add(loan.unpaidInterest);

        // Calculate defaulterEquity
        UD60x18 defaulterEquity = salePrice.sub(defaulterDebt);

        // Send defaulterEquity to defaulter
        USDC.safeTransferFrom(address(this), loan.borrower, fromUD60x18(defaulterEquity));

        // Reset loan state to Null (so it can re-enter system later)
        loan.borrower = address(0);
    }
}
