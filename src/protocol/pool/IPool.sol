// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../types/Property.sol";

interface IPool {
    function availableLiquidity() external view returns (uint);
}
