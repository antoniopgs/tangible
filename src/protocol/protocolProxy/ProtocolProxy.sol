// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/state/State.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

contract ProtocolProxy is State, ERC721Holder, Proxy {
    
    function _implementation() internal view override returns (address target) {
        target = logicTargets[msg.sig];
        require(target != address(0), "sig has no target");
    }
}