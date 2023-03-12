// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";

contract Interest is IInterest {

    // IPool pool;
    UD60x18 yearlyBorrowerRate;

    constructor(uint borrowerAprPct) {
        yearlyBorrowerRate = toUD60x18(borrowerAprPct).div(toUD60x18(100));
    }

    function calculateYearlyBorrowerRate(UD60x18 utilization) external view returns (UD60x18) {

        // Return yearlyBorrowerRate
        return yearlyBorrowerRate;
    }
}
