// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "..//state/State.sol";
import { SD59x18, toSD59x18 } from "@prb/math/src/SD59x18.sol";
import { fromUD60x18 } from "@prb/math/src/UD60x18.sol";

abstract contract Status is State {
    
    function status(uint tokenId) public view returns (Status) {

        Loan memory loan = _loans[tokenId];
        
        // If no borrower
        if (loan.borrower == address(0)) { // Note: acceptBid() must clear-out borrower & acceptLoanBid() must update borrower
            return Status.None;

        // If borrower
        } else {
            
            // If default
            if (defaulted(tokenId)) { // Note: payLoan() must clear-out borrower in finalPayment
                
                // Calculate timeSinceDefault
                uint timeSinceDefault = block.timestamp - defaultTime(loan);

                if (timeSinceDefault <= redemptionWindow) {
                    return Status.Default; // Note: foreclose() must clear-out borrower & loanForeclose() must update borrower
                } else {
                    return Status.Foreclosurable;
                }

            // If no default
            } else {
                return Status.Mortgage;
            }
        }
    }

    function defaulted(uint tokenId) private view returns(bool) {

        // Get loan
        Loan memory loan = _loans[tokenId];

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(loan);

        // Calculate loanMaxDurationMonths
        uint loanMaxDurationMonths = loan.maxDurationSeconds / yearSeconds * yearMonths;

        // If loan exceeded allowed months
        if (_loanCompletedMonths > loanMaxDurationMonths) {
            return true;
        }

        return loan.unpaidPrincipal > principalCap(loan, _loanCompletedMonths);
    }

    // Note: truncates on purpose (to enforce payment after monthSeconds, but not every second)
    function loanCompletedMonths(Loan memory loan) private view returns(uint) {
        uint completedMonths = (block.timestamp - loan.startTime) / monthSeconds;
        uint _loanMaxMonths = loanMaxMonths(loan);
        return completedMonths > _loanMaxMonths ? _loanMaxMonths : completedMonths;
    }

    function loanMaxMonths(Loan memory loan) private pure returns (uint) {
        return yearMonths * loan.maxDurationSeconds / yearSeconds;
    }

    function principalCap(Loan memory loan, uint month) public pure returns(uint cap) {

        // Ensure month doesn't exceed loanMaxDurationMonths
        require(month <= loanMaxMonths(loan), "month must be <= loanMaxDurationMonths");

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = toSD59x18(int(elapsedSeconds)).sub(toSD59x18(int(loan.maxDurationSeconds))).sub(toSD59x18(1));

        // Calculate numerator
        SD59x18 z = toSD59x18(1).sub(SD59x18.wrap(int(UD60x18.unwrap(toUD60x18(1).add(loan.ratePerSecond)))).pow(negExponent));
        UD60x18 numerator = UD60x18.wrap(uint(SD59x18.unwrap(SD59x18.wrap(int(UD60x18.unwrap(loan.paymentPerSecond))).mul(z))));

        // Calculate cap
        cap = fromUD60x18(numerator.div(loan.ratePerSecond));
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function defaultTime(Loan memory loan) private view returns (uint _defaultTime) {

        uint completedMonths = loanCompletedMonths(loan);

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) {

            uint completedMonthPrincipalCap = principalCap(loan, i);
            uint prevCompletedMonthPrincipalCap = principalCap(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _defaultTime = loan.startTime + (i * monthSeconds);
            }
        }
    }
}
