// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IWhitelist {

    function verifyResident(address addr, uint resident) external;
}