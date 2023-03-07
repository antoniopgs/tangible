// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./Config.sol";
import "../roles/RoleNames.sol";

abstract contract ConfigUser is ReentrancyGuardUpgradeable {

    Config internal config;

    function __ConfigUser_init(Config _config) internal onlyInitializing {
        config = _config;
    }

    function setConfig(Config _config) external onlyConfigRole(CONFIG_MANAGER) {
        config = _config;
    }

    modifier onlyConfigRole(bytes32 role) {
        require(config.hasRole(role, msg.sender), "caller doesn't have role");
        _;
    }
}