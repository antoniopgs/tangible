// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../state/state/State.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SD59x18, convert } from "@prb/math/src/SD59x18.sol";

abstract contract Amortization is State {

    UD60x18 immutable one = convert(uint(1));

    using SafeCast for uint;

    function balanceAtSecond(Loan memory loan, uint second) private view returns(uint) {
        require(second <= loan.maxDurationSeconds, "second not <= maxDurationSeconds");
        SD59x18 exponent = convert(second.toInt256() - loan.maxDurationSeconds.toInt256());
        SD59x18 b = one.add(loan.ratePerSecond).intoSD59x18().pow(exponent);
        return convert(loan.paymentPerSecond.mul(one.sub(b.intoUD60x18())).div(loan.ratePerSecond));
    }

    function loanMonthStartSecond(uint loanMonth) internal pure returns(uint) {
        return (loanMonth - 1) * SECONDS_IN_MONTH;
    }

    function principalCapAtMonth(Loan memory loan, uint loanMonth) internal view returns(uint) {
        
        // Get loanMonthStartSecond
        uint _loanMonthStartSecond = loanMonthStartSecond(loanMonth);

        // If second in question exceeds loan max duration
        if (_loanMonthStartSecond > loan.maxDurationSeconds) {
            return 0; // there should be no unpaid principal left

        } else {
            return balanceAtSecond(loan, _loanMonthStartSecond);
        }
    }

    function loanCurrentMonth(Loan memory loan) public view returns(uint) {
        uint activeTime = block.timestamp - loan.startTime;
        return (activeTime / SECONDS_IN_MONTH) + 1; // Note: activeTime / SECONDS_IN_MONTH always rounds down
    }

    function currentPrincipalCap(Loan memory loan) internal view returns(uint) {
        
        // Get loanCurrentMonth
        uint _loanCurrentMonth = loanCurrentMonth(loan);
        
        // If first month
        if (_loanCurrentMonth == 1) {
            // Note: return unpaidPrincipal to avoid precision bugs
            // Note: this means the cap will drop with every payment in 1st month (but not other months). shouldn't cause problems, but revisit later
            return loan.unpaidPrincipal;

        } else {
            return principalCapAtMonth(loan, _loanCurrentMonth);
        }
    }
}