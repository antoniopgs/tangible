// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

contract Registry {

    mapping(address account => bool resident) internal _residents;
    mapping(address account => bool notAmerican) internal _notAmericans;

    function isResident(address account) external view returns(bool) {
        return _residents[account];
    }

    function isNotAmerican(address account) external view returns(bool) {
        return _notAmericans[account];
    }
}