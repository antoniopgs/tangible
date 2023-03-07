// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./RoleNames.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; // Question: do I need this?

abstract contract Roles is AccessControlUpgradeable/*, ReentrancyGuardUpgradeable */ {
    
    function __RolesUpgradeable_init() internal onlyInitializing {
        __AccessControl_init();
        // __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}