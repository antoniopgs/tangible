// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IPool.sol";

abstract contract Pool is IPool {

    // Math Vars
    UD60x18 internal totalBorrowed;
    UD60x18 internal totalDeposits;

    // function lenderApy() external view returns (UD60x18) {
    //     return perfectLenderApy.mul(utilization());
    // }
}
