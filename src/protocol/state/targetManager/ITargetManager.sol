// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITargetManager {
    function getTarget(string calldata signature) external view returns (address);
    function setSigsTarget(bytes4[] calldata selectorsArr, address target) external;
    function initializeTarget(address target) external;
}