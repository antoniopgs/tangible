// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./ITargetManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract TargetManager is ITargetManager, Ownable {

    mapping (bytes4 => address) public logicTargets;

    function getTarget(string calldata sig) external view returns (address) {
        return logicTargets[bytes4(keccak256(abi.encodePacked(sig)))];
    }

    function setTargets(string[] calldata sigsArr, address[] calldata targetsArr) external onlyOwner {
        require(sigsArr.length == targetsArr.length, "unequal array lengths");

        for (uint256 i = 0; i < sigsArr.length; i++) {
            logicTargets[bytes4(keccak256(abi.encodePacked(sigsArr[i])))] = targetsArr[i];
        }
    }

    function initializeTarget(address target) external onlyOwner {
        (bool success,) = target.delegatecall(abi.encodeWithSignature("initialize(address)", target));
        require(success, "target initialization failed");
    }
}