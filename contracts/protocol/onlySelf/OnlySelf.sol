// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

abstract contract OnlySelf {

    modifier onlySelf {
        require(msg.sender == address(this), "onlySelf: caller not address(this)");
        _;
    }
}