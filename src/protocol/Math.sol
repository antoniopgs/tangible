// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

abstract contract Math {

    struct Loan {
        UD60x18 tUsdcBalance;
    }

    // Exponent Vars
    uint private lastOperationTime;
    UD60x18 internal borrowerRateSecond;

    // System Vars
    UD60x18 internal savedOutstandingDebt;
    UD60x18 internal borrowed; // maybe I can get rid of this?
    UD60x18 internal deposits;

    function lastOperationTimeDelta() private view returns(UD60x18) {
        return toUD60x18(block.timestamp - lastOperationTime);
    }

    function currentExponent() internal view returns(UD60x18) {
        return borrowerRateSecond.mul(lastOperationTimeDelta());
    }

    function outstandingDebt() public view returns (UD60x18) {
        return savedOutstandingDebt.mul(currentExponent().exp());
    }

    function interestOwed() public view returns (UD60x18) {
        return outstandingDebt().sub(borrowed);
    }

    function utilization() public view returns (UD60x18) {
        return borrowed.div(deposits);
    }

    function borrowerRateWeightedAvg() public view returns (UD60x18) {
        // return apy / utilization() // less efficient
        return interestOwed().div(borrowed);
    }

    function borrowerDebt(Loan memory loan) public view returns (UD60x18) {
        return loan.tUsdcBalance.mul(toUD60x18(1).add(borrowerRateWeightedAvg())); // 1 + w might just be my new tUsdc ratio?
    }

    function foreclose(Loan memory loan) external {
        savedOutstandingDebt = outstandingDebt() - borrowedDebt(loan); // have to remove the future, not the past
        loan.tUsdcBalance = 0;
    }
}
