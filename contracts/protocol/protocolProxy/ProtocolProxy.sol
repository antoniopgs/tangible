// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../state/targetManager/TargetManager.sol";

contract ProtocolProxy is TargetManager, Proxy {

    function _implementation() internal view override returns (address target) {
        target = logicTargets[msg.sig];
        require(target != address(0), "sig has no target");
    }

    receive() external payable {
        // Todo: implement logic
    }
}
