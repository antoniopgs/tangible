// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./IDebtsMath.sol";
import "../state/state/State.sol";
import { SD59x18, convert } from "@prb/math/src/SD59x18.sol";
import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";
import { intoSD59x18 } from "@prb/math/src/ud60x18/Casting.sol";
import { Loan, Status } from "../../types/Types.sol";

abstract contract DebtsMath is IDebtsMath, State {

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

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

    function redeemable(Loan memory loan) internal view returns(bool) {
        uint timeSinceDefault = block.timestamp - defaultTime(loan);
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

    function borrowerRatePerSecond(UD60x18 utilization) internal view returns(UD60x18 ratePerSecond) {
        ratePerSecond = borrowerApr(utilization).div(convert(yearSeconds)); // Todo: improve precision
    }

    function borrowerApr(UD60x18 utilization) public view returns(UD60x18 apr) {

        assert(utilization.lte(convert(uint(1)))); // Note: utilization should never exceed 100%

        if (utilization.lte(optimalUtilization)) {
            apr = m1.mul(utilization).add(b1);

        } else if (utilization.gt(optimalUtilization) && utilization.lt(convert(uint(1)))) {
            SD59x18 x = intoSD59x18(m2.mul(utilization));
            apr = intoUD60x18(x.add(b2()));

        } else if (utilization.eq(convert(uint(1)))) {
            revert("no APR. can't start loan if utilization = 100%");
        }

        assert(apr.gt(convert(uint(0))));
        assert(apr.lt(convert(uint(1))));
    }

    function b2() private view returns(SD59x18) {
        SD59x18 x = intoSD59x18(m1).sub(intoSD59x18(m2));
        SD59x18 y = intoSD59x18(optimalUtilization).mul(x);
        return y.add(intoSD59x18(b1));
    }

    function loanChart(uint tokenId) external view returns(uint[] memory x, uint[] memory y) {

        // Get loan
        Loan memory loan = debts[tokenId].loan;

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
}