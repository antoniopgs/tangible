// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ILoanStatus.sol";
import "../state/state/State.sol";
import { Loan } from "../../types/Types.sol";
import { SD59x18, convert } from "@prb/math/src/SD59x18.sol";
import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";
import { intoSD59x18 } from "@prb/math/src/ud60x18/Casting.sol";

abstract contract LoanStatus is ILoanStatus, State {

    function status(uint tokenId) external view returns(Status) {
        return status(_debts[tokenId].loan);
    }

    function status(Loan memory loan) internal view returns (Status) {
        
        if (loan.unpaidPrincipal == 0) {
            return Status.ResidentOwned;

        } else {
            
            if (defaulted(loan)) {
                return Status.Default;

            } else {
                return Status.Mortgage;
            }
        }
    }

    function defaulted(Loan memory loan) private view returns(bool) {

        // Get loanCompletedMonths
        uint _loanCompletedMonths = loanCompletedMonths(loan);

        if (_loanCompletedMonths == 0) {
            return false;
        }

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

    function principalCap(Loan memory loan, uint month) private pure returns(uint cap) {

        // Ensure month doesn't exceed loanMaxDurationMonths
        require(month <= loanMaxMonths(loan), "month must be <= loanMaxDurationMonths");

        // Calculate elapsedSeconds
        uint elapsedSeconds = month * monthSeconds;

        // Calculate negExponent
        SD59x18 negExponent = convert(int(elapsedSeconds)).sub(convert(int(loan.maxDurationSeconds))).sub(convert(int(1)));

        // Calculate numerator
        SD59x18 z = convert(int(1)).sub(intoSD59x18(convert(uint(1)).add(loan.ratePerSecond)).pow(negExponent));
        UD60x18 numerator = intoUD60x18(intoSD59x18(loan.paymentPerSecond).mul(z));

        // Calculate cap
        cap = convert(numerator.div(loan.ratePerSecond));
    }

    function redeemable(uint tokenId) public view returns(bool) {
        uint timeSinceDefault = block.timestamp - defaultTime(_debts[tokenId].loan);
        return timeSinceDefault <= redemptionWindow;
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function defaultTime(Loan memory loan) private view returns (uint _defaultTime) {

        uint completedMonths = loanCompletedMonths(loan);

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) { // Todo: reduce gas costs

            uint completedMonthPrincipalCap = principalCap(loan, i);
            uint prevCompletedMonthPrincipalCap = i == 1 ? loan.unpaidPrincipal : principalCap(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _defaultTime = loan.startTime + (i * monthSeconds);
            }
        }

        assert(_defaultTime > 0);
    }

    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y) {

        // Get loan
        Loan memory loan = _debts[tokenId].loan;

        // Loop loan months
        for (uint i = 0; i <= loanMaxMonths(loan); i++) {
            
            // Add month to x
            // x.push(i);
            x[i] = i;

            // Add month's principal cap to y
            // y.push(principalCap(loan, i));
            y[i] = principalCap(loan, i);
        }
    }

    // Todo: add otherDebt later?
    function _bidActionable(Bid memory _bid, uint minSalePrice) internal view returns(bool) {

        // Calculate bid principal
        uint principal = _bid.propertyValue - _bid.downPayment;

        // Calculate bid ltv
        UD60x18 ltv = convert(principal).div(convert(_bid.propertyValue));

        // Return actionability
        return (
            principal <= _availableLiquidity() &&
            ltv.lte(_maxLtv) && // Note: LTV already validated in bid(), but re-validate it here (because admin may have updated it)
            _bid.propertyValue >= minSalePrice
        );
    }

    function _availableLiquidity() internal view returns(uint) {
        return totalDeposits - totalPrincipal; // - protocolMoney?
    }

    function _minSalePrice(Loan memory loan) internal view returns(uint) {
        UD60x18 saleFeeSpread = status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        return convert(convert(loan.unpaidPrincipal + _accruedInterest(loan)).div(convert(uint(1)).sub(saleFeeSpread)));
    }

    function highestActionableBid(uint tokenId) internal view returns (uint highestActionableIdx) {

        // Get minSalePrice
        uint minSalePrice = _minSalePrice(_debts[tokenId].loan);

        // Get tokenBids
        Bid[] memory tokenBids = _bids[tokenId];

        // Loop tokenBids
        for (uint i = 0; i < tokenBids.length; i++) {

            // Get bid
            Bid memory bid = tokenBids[i];

            // If bid has higher propertyValue and is actionable
            if (bid.propertyValue > tokenBids[highestActionableIdx].propertyValue && _bidActionable(bid, minSalePrice)) {

                // Update highestActionableIdx // Note: might run into problems if nothing is returned and it defaults to 0
                highestActionableIdx = i;
            }    
        }
    }
}