// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../types/TimeConstants.sol";
import { Loan, Status } from "../../types/Types.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract Amortization {

    UD60x18 immutable one = convert(uint(1));

    function balanceAtSecond(Loan memory loan, uint second) private view returns(uint) {
        return convert(loan.paymentPerSecond.mul(one.sub(one.add(loan.ratePerSecond).pow(convert(second - loan.maxDurationSeconds)))).div(loan.ratePerSecond));
    }

    function loanMonthStartSecond(uint loanMonth) internal pure returns(uint) {
        return (loanMonth - 1) * monthSeconds;
    }

    function principalCapAtMonth(Loan memory loan, uint loanMonth) internal view returns(uint) {
        return balanceAtSecond(loan, loanMonthStartSecond(loanMonth));
    }

    function loanCurrentMonth(Loan memory loan) public view returns(uint) {
        uint activeTime = block.timestamp - loan.startTime;
        return (activeTime / monthSeconds) + 1; // Note: activeTime / monthSeconds always rounds down
    }

    function currentPrincipalCap(Loan memory loan) internal view returns(uint) {
        return principalCapAtMonth(loan, loanCurrentMonth(loan));
    }
}