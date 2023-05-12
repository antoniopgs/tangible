// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IInterest.sol";
import "../state/status/Status.sol";
import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";

contract Interest is IInterest, Status {

    function borrowerRatePerSecond(UD60x18 utilization) public view returns(UD60x18 ratePerSecond) {
        ratePerSecond = borrowerApr(utilization).div(toUD60x18(yearSeconds)); // Todo: improve precision
    }

    function borrowerApr(UD60x18 utilization) public view returns(UD60x18 apr) {

        assert(utilization.lte(toUD60x18(1))); // Note: utilization should never exceed 100%

        if (utilization.lte(optimalUtilization)) {
            apr = m1.mul(utilization).add(b1);

        } else if (utilization.gt(optimalUtilization) && utilization.lt(toUD60x18(1))) {
            SD59x18 x = intoSD59x18(m2.mul(utilization));
            apr = intoUD60x18(x.add(b2()));

        } else if (utilization.eq(toUD60x18(1))) {
            revert("no APR. can't start loan if utilization = 100%");
        }

        assert(apr.gt(toUD60x18(0)));
        assert(apr.lt(toUD60x18(1)));
    }

    function b2() private view returns(SD59x18) {
        SD59x18 x = intoSD59x18(m1).sub(intoSD59x18(m2));
        SD59x18 y = intoSD59x18(optimalUtilization).mul(x);
        return y.add(intoSD59x18(b1));
    }
}
