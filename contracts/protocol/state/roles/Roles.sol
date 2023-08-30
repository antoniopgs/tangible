// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import { TANGIBLE, GSP, PAC } from "../../../types/RoleNames.sol";

abstract contract Roles is AccessControl { // Todo: Later, make an AccessControlState contract (to be able to remove Roles from State inheritance)

    function initializeRoles(address tangible, address gsp, address pac) internal { // Note: all params should be Multi-Sigs // Note: maybe move to initializer later
        _grantRole(TANGIBLE, tangible);
        _grantRole(GSP, gsp);
        _grantRole(PAC, pac);
    }
}