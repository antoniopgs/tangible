// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./RoleNames.sol";

abstract contract RolesUpgradeable is AccessControlUpgradeable, ReentrancyGuardUpgradeable, RoleNames {
    
    function __RolesUpgradeable_init() internal onlyInitializing {
        __AccessControl_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}