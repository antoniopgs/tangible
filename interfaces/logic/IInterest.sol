// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IInterest {
    function calculateNewRatePerSecond(UD60x18 utilization) external view returns(UD60x18);
}