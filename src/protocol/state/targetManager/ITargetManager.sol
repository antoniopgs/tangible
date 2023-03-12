// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface ITargetManager {
    function getTarget(string calldata signature) external view returns (address);
    function setTargets(string[] calldata signatures, address[] calldata targets) external;
    function initializeTarget(address target) external;
}