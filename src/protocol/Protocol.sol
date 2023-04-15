// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/State.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

contract Protocol is State, Proxy {
    
    function _implementation() internal view override returns (address) {
        return logicTargets[msg.sig];
    }
}