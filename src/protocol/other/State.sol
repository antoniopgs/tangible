// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract State {

    enum NftState { Null, Mortgage, Default, Foreclosed }

    uint public allowedDelayedPayments = 2;

    function state(Loan memory loan) internal view returns (NftState) {
        
        // If no borrower
        if (loan.borrower == address(0)) {
            return NftState.Null;

        // If borrower
        } else {
            
            // If not defaulted
            if (!defaulted(loan)) {
                
                // If positive payment deadline
                if (loan.nextPaymentDeadline > 0 ) {
                    return NftState.Mortgage;

                // If no payment deadline
                } else {
                    return NftState.Foreclosed;
                }

            // If defaulted
            } else {
                return NftState.Default;
            }
        }
    }

    // I might want to talk to Nick Dranias, to get a more clear view on how this is allowed to work
    function defaulted(Loan memory loan) private view returns (bool) {
        return block.timestamp > loan.nextPaymentDeadline + (30 days * allowedDelayedPayments); // REDO THIS
    }
}
