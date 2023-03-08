// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./IConfig.sol";
import "../roles/RoleNames.sol";
import "./ConfigNames.sol";

abstract contract ConfigUser is ReentrancyGuardUpgradeable {

    IConfig internal config;

    function __ConfigUser_init(IConfig _config) internal onlyInitializing {
        config = _config;
    }

    function setConfig(IConfig _config) external onlyConfigRole(CONFIG_MANAGER) {
        config = _config;
    }

    modifier onlyConfigRole(bytes32 role) {
        require(config.hasRole(role, msg.sender), "caller doesn't have role");
        _;
    }
}