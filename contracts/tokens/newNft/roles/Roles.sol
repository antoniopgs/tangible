// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Roles is AccessControl {

    // Roles (should only be assigned to Multi-Sigs)
    bytes32 public constant TANGIBLE = keccak256("TANGIBLE"); // Note: Tangible LLC
    bytes32 public constant GSP = keccak256("GSP"); // Note: General Service Provider
    bytes32 public constant PAC = keccak256("PAC"); // Note: Prospera Arbitration Center

    constructor(address tangible, address gsp, address pac) { // Note: should all be Multi-Sigs
        _grantRole(TANGIBLE, tangible);
        _grantRole(GSP, gsp);
        _grantRole(PAC, pac);
    }

    // function mint(address to, uint256 amount) public {
    //     // Check that the calling account has the minter role
    //     require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
    //     _mint(to, amount);
    // }
}