// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";
// import { Loan } from "../../types/Types.sol";
// import { SD59x18, convert } from "@prb/math/src/SD59x18.sol";
// import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";
// import { intoSD59x18 } from "@prb/math/src/ud60x18/Casting.sol";
import "./Amortization.sol";

abstract contract LoanStatus is State, Amortization {

    // Note: return defaultTime here too?
    function defaulted(Loan memory loan) private view returns(bool _defaulted) {
        return loan.unpaidPrincipal > currentPrincipalCap(loan);
    }

    function _status(Loan memory loan) internal view returns(Status) {

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

    function _redeemable(uint tokenId) internal view returns(bool) {
        uint timeSinceDefault = block.timestamp - defaultTime(_debts[tokenId].loan);
        return timeSinceDefault <= _redemptionWindow;
    }

    // Note: gas expensive
    // Note: if return = 0, no default
    function defaultTime(Loan memory loan) private view returns (uint _defaultTime) {

        uint completedMonths = loanCompletedMonths(loan);

        // Loop backwards from loanCompletedMonths
        for (uint i = completedMonths; i > 0; i--) { // Todo: reduce gas costs

            uint completedMonthPrincipalCap = _principalCap(loan, i);
            uint prevCompletedMonthPrincipalCap = i == 1 ? loan.unpaidPrincipal : _principalCap(loan, i - 1);

            if (loan.unpaidPrincipal > completedMonthPrincipalCap && loan.unpaidPrincipal <= prevCompletedMonthPrincipalCap) {
                _defaultTime = loan.startTime + (i * monthSeconds);
            }
        }

        assert(_defaultTime > 0);
    }



    
    function _availableLiquidity() internal view returns(uint) {
        return _totalDeposits - _totalPrincipal; // - protocolMoney?
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

    function _minSalePrice(Loan memory loan) internal view returns(uint) {
        UD60x18 saleFeeSpread = _status(loan) == Status.Default ? _baseSaleFeeSpread.add(_defaultFeeSpread) : _baseSaleFeeSpread; // Question: maybe defaultFee should be a boost appplied to interest instead?
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

        if (tokenBids.length == 0) {
            revert("token has no bids");
            
        } else if (highestActionableIdx == 0 && !_bidActionable(tokenBids[0], minSalePrice)) {
            revert("token has no actionable bids");
        }
    }
}