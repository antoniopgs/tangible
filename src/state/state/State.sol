// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "./IState.sol";
import "../targetManager/TargetManager.sol";
import "../whitelisting/Whitelisting.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../tokens/tUsdc.sol";
import { toUD60x18 } from "@prb/math/UD60x18.sol";

abstract contract State is IState, TargetManager, Whitelisting, Initializable {

    // Tokens
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // Note: ethereum mainnet
    tUsdc tUSDC;

    // Time constants
    uint /* private */ public constant yearSeconds = 365 days; // Note: made public for testing
    uint /* private */ public constant yearMonths = 12;
    uint /* private */ public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    // Pool vars
    uint public totalPrincipal;
    uint public totalDeposits;
    uint public maxTotalUnpaidInterest;
    UD60x18 public optimalUtilization = toUD60x18(90).div(toUD60x18(100)); // Note: 90%

    // Interest vars
    UD60x18 internal m1 = toUD60x18(4).div(toUD60x18(100)); // Note: 0.04
    UD60x18 internal b1 = toUD60x18(3).div(toUD60x18(100)); // Note: 0.03
    UD60x18 internal m2 = toUD60x18(9); // Note: 9

    // Loan storage
    mapping(uint => Loan) internal _loans;

    // Other vars
    uint internal redemptionWindow = 45 days;

    UD60x18 internal payLoanFeeSpread = toUD60x18(1).div(toUD60x18(100)); // Note: 1%
    UD60x18 internal _redemptionFeeSpread = toUD60x18(2).div(toUD60x18(100)); // Note: 2%
    UD60x18 internal _foreclosureFeeSpread = toUD60x18(3).div(toUD60x18(100)); // Note: 3%

    function redemptionFeeSpread() external view returns (UD60x18) {
        return _redemptionFeeSpread;
    }

    function foreclosureFeeSpread() external view returns (UD60x18) {
        return _foreclosureFeeSpread;
    }

    function loans(uint tokenId) external view returns(Loan memory) {
        return _loans[tokenId];
    }

    function initialize(tUsdc _tUSDC) external initializer { // Question: maybe move this elsewhere?
        tUSDC = _tUSDC;
    }
}