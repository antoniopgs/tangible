// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "lib/prb-math/contracts/PRBMathUD60x18Typed.sol";
type PropertyId is uint;

contract Math {

    uint private constant secondsInYear = 365 * 24 * 60 * 60;

    struct Loan {
        uint takeoutTime;
        PRBMath.UD60x18 principal;
        PRBMath.UD60x18 totalRepaid;
    }

    PRBMath.UD60x18 internal totalSupplied;
    PRBMath.UD60x18 internal totalBorrowed;

    mapping(PropertyId => Loan) private loans;

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

    function utilization() private view returns(PRBMath.UD60x18 memory) {
        return totalBorrowed.div(totalSupplied); // should the numerator be "totalBorrowed" or "systemDebt"?
    }

    // this might be wrong.
    // due to interest, suppliers will withdraw more than they initially supply.
    // totalSupplied might underflow
    function availableToBorrow() private view returns (PRBMath.UD60x18 memory) {
        return totalSupplied.sub(totalBorrowed);
    }

    function takeoutLoan() external {

    }

    function repay(PropertyId propertyId, PRBMath.UD60x18 memory repayment) external {

        // Get totalRepaid
        PRBMath.UD60x18 storage totalRepaid = loans[propertyId].totalRepaid;

        // Increase totalRepaid
        totalRepaid.value = totalRepaid.add(repayment).value;
    }


    uint totalDebt;
    uint totalSupply;

    function utilization() private view returns (uint) {
        return totalDebt / totalSupply;
    }

    function deposit(uint deposit) {
        totalSupply += deposit;
    }

    function withdraw(uint withdrawal) {
        totalSupply -= withdrawal;
    }

    function borrow(uint principal) {
        totalDebt += principal * (1 + interest);
        totalSupply += principal * (1 + interest);
    }

    function repay(uint repayment) {
        totalDebt -= repayment;
    }
}