// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

import "forge-std/console.sol";

contract ProtocolProxy is State, Proxy {
    
    function _implementation() internal view override returns (address target) {
        console.log("_implementation...");
        console.logBytes4(msg.sig);
        console.log("logicTargets[msg.sig]:", logicTargets[msg.sig]);
        target = logicTargets[msg.sig];
        require(target != address(0), "sig has no target");
    }
}