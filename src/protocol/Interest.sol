// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

contract Interest {

    UD60x18 private immutable yearSeconds = toUD60x18(365 * 24 * 60 * 60);
    UD60x18 private borrowerRateYearPct = toUD60x18(5);

    function borrowerRateSecond() external view returns (UD60x18) {
        return borrowerRateYearPct.div(toUD60x18(100).mul(yearSeconds));
    }
}
