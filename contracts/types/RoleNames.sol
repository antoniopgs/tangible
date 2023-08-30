// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Roles (should only be assigned to Multi-Sigs)
bytes32 constant TANGIBLE = keccak256("TANGIBLE"); // Note: Tangible LLC
bytes32 constant GSP = keccak256("GSP"); // Note: General Service Provider
bytes32 constant PAC = keccak256("PAC"); // Note: Prospera Arbitration Center