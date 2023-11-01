// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../targetManager/TargetManager.sol";
import "../../../tokens/SharesToken.sol";

abstract contract State is TargetManager {

    // Links
    IERC20 public UNDERLYING;
    SharesToken public YIELD;

    // Pool
    uint internal _totalPrincipal;
    uint internal _totalDeposits;

    // Whitelist
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;
    mapping(address => bool) internal _notAmerican;

    // function _isResident(address addr) internal view returns (bool) {
    //     return _addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    // }
}