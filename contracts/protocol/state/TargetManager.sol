// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/state/ITargetManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract TargetManager is ITargetManager, Ownable(msg.sender) {

    mapping (bytes4 => address) public logicTargets; // Todo: maybe make public and move to Info?

    // Note: add safety mechanism to avoid function selector key collisions
    function setSelectorsTarget(bytes4[] calldata selectorsArr, address target) external onlyOwner {

        for (uint256 i = 0; i < selectorsArr.length; i++) {
            logicTargets[selectorsArr[i]] = target;
        }
    }
}