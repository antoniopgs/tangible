// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./IConfig.sol";
import "../roles/Roles.sol";
import "./ConfigNames.sol";

contract Config is IConfig, Roles {

    // State
    mapping(bytes32 => address) public addressStorage;
    mapping(bytes32 => uint) public uintStorage;
    mapping(bytes32 => UD60x18) public UD60x18Storage;
    
    function initialize(ProtocolContracts memory protocolContracts) external initializer { 

        // grant roles
        grantRoles(protocolContracts);

        // set links
        setLinks(protocolContracts);

        // set vars
        setVars();
    }

    function grantRoles(ProtocolContracts memory protocolContracts) private {
        grantRole(CONFIG_MANAGER, msg.sender);
        grantRole(PROPERTY_MANAGER, msg.sender);
        grantRole(BID_MANAGER, protocolContracts.auctions);
        grantRole(LOAN_MANAGER, protocolContracts.borrowing);
    }

    function setLinks(ProtocolContracts memory protocolContracts) private {
        setAddress(auctions, protocolContracts.auctions);
        setAddress(automation, protocolContracts.automation);
        setAddress(borrowing, protocolContracts.borrowing);
        setAddress(foreclosures, protocolContracts.foreclosures);
        setAddress(interest, protocolContracts.interest);
        setAddress(lending, protocolContracts.lending);
        setAddress(pool, protocolContracts.pool);
        setAddress(vault, protocolContracts.vault);
    }

    function setVars() private {

    }

    // ----- GETTERS -----
    function getAddress(bytes32 key) external view returns(address) {
        return addressStorage[key];
    }

    function getUint(bytes32 key) external view returns(uint) {
        return uintStorage[key];
    }

    function getUD60x18(bytes32 key) external view returns(UD60x18) {
        return UD60x18Storage[key];
    }

    // ----- SETTERS -----
    function setAddress(bytes32 key, address newVal) public onlyRole(CONFIG_MANAGER) {
        addressStorage[key] = newVal;
    }

    function setUint(bytes32 key, uint newVal) public onlyRole(CONFIG_MANAGER) {
        uintStorage[key] = newVal;
    }

    function setUD60x18(bytes32 key, UD60x18 newVal) public onlyRole(CONFIG_MANAGER) {
        UD60x18Storage[key] = newVal;
    }
}