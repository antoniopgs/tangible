// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/status/Status.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

import "forge-std/console.sol";

import "../auctions/IAuctions.sol";

contract ProtocolProxy is Status, ERC721Holder, Proxy {
    
    function _implementation() internal view override returns (address target) {
        target = logicTargets[msg.sig];
        console.logBytes4(msg.sig);
        console.logBytes4(IAuctions.acceptBid.selector);
        require(target != address(0), "sig has no target");
    }
}