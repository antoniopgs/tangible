// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "prb/math/contracts/PRBMathUD60x18Typed.sol";

contract Math {

    struct Loan {
        uint takeoutTime;
        uint principal;
        uint totalRepaid;
    }

    uint private constant secondsInYear = 365 * 24 * 60 * 60;
    PRBMath.UD60x18 private ratePerSecond = 5.div(100).div(secondsInYear);

    function loanSeconds(Loan memory loan) private returns(uint) {
        block.timestamp - loan.takeoutTime;
    }

    function borrowerDebt(Loan memory loan) private {
        loan.principal * (1 + ratePerSecond * loanSeconds(loan)) - loan.totalRepaid;
    }
}