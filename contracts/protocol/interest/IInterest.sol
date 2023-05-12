// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/src/UD60x18.sol";

interface IInterest {
    function borrowerRatePerSecond(UD60x18 utilization) external view returns(UD60x18 ratePerSecond);
    function borrowerApr(UD60x18 utilization) external view returns(UD60x18 apr);
}