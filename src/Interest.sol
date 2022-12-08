// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract Interest {

    // Interest Rate Vars
    UD60x18 public optimalUtilization; // should this be here?
    UD60x18 public m1;
    UD60x18 public b1;
    UD60x18 public m2;

    function b2() private view returns (UD60x18 ) {
        return optimalUtilization.mul(m1.sub(m2)).add(b1);
    }

    function currentYearlyRate(UD60x18 utilization) external view returns (UD60x18 ) {

        // If utilization <= optimalUtilization
        if (utilization.lte(optimalUtilization)) {
            return m1.mul(utilization).add(b1);

        // If utilization > optimalUtilization
        } else {
            return m2.mul(utilization).add(b2());
        }
    }
}
