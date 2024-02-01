// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../../interfaces/state/ITargetManager.sol";
import "../Roles.sol";

abstract contract TargetManager is ITargetManager, Roles {

    mapping (bytes4 => address) public logicTargets; // Todo: maybe make public and move to Info?

    function setSelectorsTarget(bytes4[] calldata selectorsArr, address target) external /* onlyRole(TANGIBLE) */ {

        for (uint256 i = 0; i < selectorsArr.length; i++) {
            logicTargets[selectorsArr[i]] = target;
        }
    }
}