// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@prb/math/UD60x18.sol";

interface IInterest {
    function calculateBorrowerRate() external view returns (UD60x18);
}