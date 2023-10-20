// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

abstract contract TimeConstants {

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)
}