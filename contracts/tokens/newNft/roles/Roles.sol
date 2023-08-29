// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Roles is AccessControl { // Todo: Later, make an AccessControlState contract (to be able to remove Roles from State inheritance)

    // Roles (should only be assigned to Multi-Sigs)
    bytes32 public constant TANGIBLE = keccak256("TANGIBLE"); // Note: Tangible LLC
    bytes32 public constant GSP = keccak256("GSP"); // Note: General Service Provider
    bytes32 public constant PAC = keccak256("PAC"); // Note: Prospera Arbitration Center

    function initializeRoles(address tangible, address gsp, address pac) internal { // Note: all params should be Multi-Sigs // Note: maybe move to initializer later
        _grantRole(TANGIBLE, tangible);
        _grantRole(GSP, gsp);
        _grantRole(PAC, pac);
    }
}