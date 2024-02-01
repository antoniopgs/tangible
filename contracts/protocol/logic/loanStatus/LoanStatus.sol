// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./Amortization.sol";

abstract contract LoanStatus is Amortization {

    // Note: return defaultTime here too?
    function defaulted(Loan memory loan) private view returns(bool) {
        return loan.unpaidPrincipal > currentPrincipalCap(loan);
    }

    function _status(Loan memory loan) internal view returns(Status) {

        if (loan.unpaidPrincipal == 0) {
            return Status.ResidentOwned;

        } else if (defaulted(loan)) {
            return Status.Default;

        } else {
            return Status.Mortgage;
        }
    }

    function validDefaultTime(Loan memory loan, uint month) private view returns(bool valid, uint defaultTime) {

        if (loanCurrentMonth(loan) > month && loan.unpaidPrincipal >= principalCapAtMonth(loan, month)) { // Todo: rethink this
            valid = true;
            defaultTime = loanMonthStartSecond(month);
        }
    }

    function timeSinceDefault(Loan memory loan) private view returns(uint) {
        return block.timestamp - _defaultTime(loan);
    }

    function _redeemable(Loan memory loan) internal view returns(bool) {
        return timeSinceDefault(loan) <= _redemptionWindow;
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function _defaultTime(Loan memory loan) internal view returns (uint _loanDefaultTime) {

        uint completedMonths = (block.timestamp - loan.startTime) / SECONDS_IN_MONTH; // Note: might be missing + 1

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) { // Todo: reduce gas costs

            uint completedMonthPrincipalCap = principalCapAtMonth(loan, i);
            uint prevCompletedMonthPrincipalCap = i == 1 ? loan.unpaidPrincipal : principalCapAtMonth(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _loanDefaultTime = loan.startTime + (i * SECONDS_IN_MONTH);
            }
        }

        assert(_loanDefaultTime > 0);
    }

    // Todo: add otherDebt later?
    function _bidActionable(Bid memory _bid, uint minSalePrice) internal view returns(bool) { // Todo: move this to Auctions.sol?

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

    function _minSalePrice(Loan memory loan) internal view returns(uint) {
        UD60x18 saleFeeSpread = _status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
        return convert(convert(loan.unpaidPrincipal + _accruedInterest(loan)).div(convert(uint(1)).sub(saleFeeSpread)));
    }

    function highestActionableBid(uint tokenId) internal view returns (uint highestActionableIdx) {

        // Get tokenBids
        Bid[] memory tokenBids = _bids[tokenId];

        if (tokenBids.length == 0) {
            revert("token has no bids");
        }

        // Get minSalePrice
        uint minSalePrice = _minSalePrice(_debts[tokenId].loan);

        // Declare found bool
        bool found;

        // Loop tokenBids
        for (uint i = 0; i < tokenBids.length; i++) {

            // Get bid
            Bid memory bid = tokenBids[i];

            // If bid has higher propertyValue and is actionable
            // Note: If 1st index has actionable bid > wont't work (but >= will)
            if (bid.propertyValue >= tokenBids[highestActionableIdx].propertyValue && _bidActionable(bid, minSalePrice)) {
                
                // Update found if needed
                if (!found) {
                    found = true;
                }

                // Update highestActionableIdx // Note: might run into problems if nothing is returned and it defaults to 0
                highestActionableIdx = i;
            }    
        }
        
        // If no actionable bids found
        if (!found) {
            revert("token has no actionable bids");
        }
    }
}