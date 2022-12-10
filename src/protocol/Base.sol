// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./tUsdc.sol";
import "./Interest.sol";

abstract contract Base {

    // Tokens
    IERC20 public USDC;
    tUsdc public tUSDC;

    // Contract Links
    Interest interest;

    constructor(IERC20 _USDC, tUsdc _tUSDC, Interest _interest) {
        USDC = _USDC;
        tUSDC = _tUSDC;
        interest = _interest;
    }
}
