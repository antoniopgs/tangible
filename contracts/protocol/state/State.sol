// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract PrevState {

    // Pool vars
    UD60x18 public optimalUtilization = convert(90).div(convert(100)); // Note: 90%

    // Interest vars
    UD60x18 internal m1 = convert(4).div(convert(100)); // Note: 0.04
    UD60x18 internal b1 = convert(3).div(convert(100)); // Note: 0.03
    UD60x18 internal m2 = convert(9); // Note: 9

    // Fees/Spreads
    UD60x18 public _baseSaleFeeSpread = convert(1).div(convert(100)); // Note: 1%
    UD60x18 public _interestFeeSpread = convert(2).div(convert(100)); // Note: 2%
    UD60x18 public _redemptionFeeSpread = convert(3).div(convert(100)); // Note: 3%
    UD60x18 public _defaultFeeSpread = convert(4).div(convert(100)); // Note: 4%

    // Main Storage
    uint protocolMoney;

    // Other vars
    uint internal redemptionWindow = 45 days;
}