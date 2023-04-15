// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITargetManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "forge-std/console.sol";

abstract contract TargetManager is ITargetManager, Ownable {

    mapping (bytes4 => address) public logicTargets;

    function getTarget(string calldata sig) external view returns (address) {
        return logicTargets[bytes4(keccak256(abi.encodePacked(sig)))];
    }

    function setSelectorsTarget(bytes4[] calldata selectorsArr, address target) external onlyOwner {
        console.log("setSelectorsTarget...");

        for (uint256 i = 0; i < selectorsArr.length; i++) {
            console.log("i:", i);
            console.logBytes4(selectorsArr[i]);
            console.log("target:", target);
            console.log("logicTargets[selectorsArr[i]]:", logicTargets[selectorsArr[i]]);
            logicTargets[selectorsArr[i]] = target;
            console.log("logicTargets[selectorsArr[i]]:", logicTargets[selectorsArr[i]]);
            console.log("");
        }
    }

    function initializeTarget(address target) external onlyOwner {
        (bool success,) = target.delegatecall(abi.encodeWithSignature("initialize(address)", target));
        require(success, "target initialization failed");
    }
}