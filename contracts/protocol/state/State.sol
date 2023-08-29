// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";

abstract contract PrevState {

    // Fees/Spreads
    UD60x18 public _baseSaleFeeSpread = convert(1).div(convert(100)); // Note: 1%
    // UD60x18 public _interestFeeSpread = convert(2).div(convert(100)); // Note: 2%
    // UD60x18 public _redemptionFeeSpread = convert(3).div(convert(100)); // Note: 3%
    UD60x18 public _defaultFeeSpread = convert(4).div(convert(100)); // Note: 4%
}