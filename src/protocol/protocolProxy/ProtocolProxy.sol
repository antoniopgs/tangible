// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

import "forge-std/console.sol";

contract ProtocolProxy is State, ERC721Holder, Proxy {
    
    function _implementation() internal view override returns (address target) {
        console.log("i1");
        target = logicTargets[msg.sig];
        console.log("i2");
        require(target != address(0), "sig has no target");
        console.log("i3");
    }
}