// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface IResidents {

    function verifyResident(address addr, uint resident) external;
    function isResident(address addr) external view returns (bool);
}