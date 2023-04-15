// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../tokens/tUsdc.sol";
import { toUD60x18 } from "@prb/math/UD60x18.sol";

abstract contract State is IState, TargetManager, Initializable {

    // Tokens
    IERC20 USDC;
    tUsdc tUSDC;

    // Time constants
    uint /* private */ public constant yearSeconds = 365 days; // Note: made public for testing
    uint /* private */ public constant yearMonths = 12;
    uint /* private */ public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    // Pool vars
    uint public totalPrincipal;
    uint public totalDeposits;
    uint public maxTotalInterestOwed;
    UD60x18 public optimalUtilization = toUD60x18(90).div(toUD60x18(100)); // Note: 90% // Todo: relate to k1 and k2

    // Interest vars
    UD60x18 internal m1 = toUD60x18(4).div(toUD60x18(100)); // Note: 0.04
    UD60x18 internal b1 = toUD60x18(3).div(toUD60x18(100)); // Note: 0.03
    UD60x18 internal m2 = toUD60x18(9); // Note: 9

    // Loan storage
    mapping(uint => Loan) public loans;

    function initialize(tUsdc _tUSDC) external initializer { // Question: maybe move this elsewhere?
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet
        tUSDC = _tUSDC;
    }
}