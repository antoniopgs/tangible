// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../state/state/IState.sol";

interface IStatus {
    enum Status { ResidentOwned, Mortgage, Default, Foreclosurable }
}
