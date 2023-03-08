// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../types/Property.sol";

interface IPool {
    function utilization() external view returns (UD60x18);
    function availableLiquidity() external view returns (uint);
}
