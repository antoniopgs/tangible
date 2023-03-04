// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../types/Property.sol";

interface IPool {
    function availableLiquidity() external view returns (uint);
    function propertiesLength() external view returns(uint);
    function propertyAt(idx _idx) external returns(Property memory property);
}
