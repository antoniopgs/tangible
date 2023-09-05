// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../state/state/State.sol";
import { SD59x18 } from "@prb/math/src/SD59x18.sol";
import { intoSD59x18 } from "@prb/math/src/ud60x18/Casting.sol";
import { intoUD60x18 } from "@prb/math/src/sd59x18/Casting.sol";

abstract contract Interest is State {

    function borrowerRatePerSecond(UD60x18 utilization) internal view returns(UD60x18 ratePerSecond) {
        ratePerSecond = _borrowerApr(utilization).div(convert(yearSeconds)); // Todo: improve precision
    }

    function _borrowerApr(UD60x18 utilization) internal view returns(UD60x18 apr) {

        assert(utilization.lte(convert(uint(1)))); // Note: utilization should never exceed 100%

        if (utilization.lte(_optimalUtilization)) {
            apr = m1.mul(utilization).add(b1);

        } else if (utilization.gt(_optimalUtilization) && utilization.lt(convert(uint(1)))) {
            SD59x18 x = intoSD59x18(m2.mul(utilization));
            apr = intoUD60x18(x.add(b2()));

        } else if (utilization.eq(convert(uint(1)))) {
            revert("no APR. can't start loan if utilization = 100%");
        }

        assert(apr.gt(convert(uint(0))));
        assert(apr.lt(convert(uint(1))));
    }

    function b2() private view returns(SD59x18) {
        SD59x18 x = intoSD59x18(m1).sub(intoSD59x18(m2));
        SD59x18 y = intoSD59x18(_optimalUtilization).mul(x);
        return y.add(intoSD59x18(b1));
    }
}