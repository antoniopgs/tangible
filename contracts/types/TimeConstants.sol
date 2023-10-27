// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

uint constant yearSeconds = 365 days;
uint constant yearMonths = 12;
uint constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)