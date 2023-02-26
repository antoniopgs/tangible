// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../pool/Pool.sol";

contract Vault is Pool {

    enum State { Auction, Mortgage, Default } // Note: maybe could switch to: enum NftOwner { Seller, Borrower, Protocol }

    function state(tokenId _tokenId) internal view returns (State) {

        // Get property loan
        Loan memory loan = properties.get(_tokenId).loan;
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: acceptBid() must clear-out borrower & acceptLoanBid() must update borrower
            return State.Auction;

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
