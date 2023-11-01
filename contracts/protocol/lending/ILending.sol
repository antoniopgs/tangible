// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

interface ILending {
    
    // Events
    event Deposit(address depositor, uint assets, uint shares);
    event Withdraw(address withdrawer, uint assets, uint shares);

    // Functions
    function deposit(uint assets) external;
    function withdraw(uint assets) external;
}