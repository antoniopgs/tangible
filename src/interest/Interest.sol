// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";

contract Interest is IInterest {

    // IPool pool;
    UD60x18 borrowerApr;

    constructor(uint borrowerRatePct) {
        borrowerApr = toUD60x18(borrowerRatePct).div(toUD60x18(100));
    }

    function calculateBorrowerRate() external view returns (UD60x18) {

        // Get pool utilization
        // UD60x18 utilization = pool.utilization();

        // Return borrowerApr
        return borrowerApr;
    }
}
