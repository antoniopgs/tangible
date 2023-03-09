// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IPropertyState.sol";

abstract contract PropertyState is IPropertyState {

    function state(Loan calldata loan) external view returns (State) {
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: acceptBid() must clear-out borrower & acceptLoanBid() must update borrower
            return State.None;

        // If borrower
        } else {
            
            // If not defaulted // Note: payLoan() must clear-out borrower in finalPayment
            if (!defaulted(loan)) {
                return State.Mortgage;

            // If defaulted
            } else { // Note: foreclose() must clear-out borrower & loanForeclose() must update borrower
                return State.Default;
            }
        }
    }

    function defaulted(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline;
    }
}
