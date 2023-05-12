// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITargetManager.sol";

interface ITargetManager {
    function setSelectorsTarget(bytes4[] calldata selectorsArr, address target) external;
}