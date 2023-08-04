// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../state/IState.sol";

interface IStatus is IState {

    // Enums
    enum Status { ResidentOwned, Mortgage, Default, Foreclosurable }
}
