// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";

contract Math {

    uint private constant secondsInYear = 365 * 24 * 60 * 60;

    struct Loan {
        uint takeoutTime;
        PRBMath.UD60x18 principal;
        PRBMath.UD60x18 totalRepaid;
    }

    using PRBMathUD60x18Typed for PRBMath.UD60x18;
    using PRBMathUD60x18Typed for uint;

    // 5% per year in converted to seconds
    PRBMath.UD60x18 private ratePerSecond = uint(5).fromUint().div(uint(100).fromUint()).div(secondsInYear.fromUint());

    function loanSeconds(Loan memory loan) private view returns (PRBMath.UD60x18 memory) {
        return (block.timestamp - loan.takeoutTime).fromUint();
    }
    
    // y = p(1 + rt)
    function borrowerDebt(Loan memory loan) private view returns (PRBMath.UD60x18 memory) {
        return loan.principal.mul(uint(1).fromUint().add(ratePerSecond.mul(loanSeconds(loan)))).sub(loan.totalRepaid);
    }
}