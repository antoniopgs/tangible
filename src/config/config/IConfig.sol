// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@prb/math/UD60x18.sol";

interface IConfig is IAccessControlUpgradeable {

    // Structs
    struct ProtocolContracts {
        address auctions;
        address automation;
        address borrowing;
        address foreclosures;
        address interest;
        address lending;
        address pool;
        address vault;        
    }

    // ----- GETTERS -----
    function getAddress(bytes32 key) external view returns(address);
    function getUint(bytes32 key) external view returns(uint);
    function getUD60x18(bytes32 key) external view returns(UD60x18);

    // ----- SETTERS -----
    function setAddress(bytes32 key, address newVal) external;
    function setUint(bytes32 key, uint newVal) external;
    function setUD60x18(bytes32 key, UD60x18 newVal) external;
}