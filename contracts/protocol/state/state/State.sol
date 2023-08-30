// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../targetManager/TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import { Debt, Bid } from "../../../types/Types.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../tokens/tUsdc.sol";

abstract contract State is TargetManager {

    // Pool
    uint public totalPrincipal;
    uint public totalDeposits;
    UD60x18 public optimalUtilization = convert(90).div(convert(100)); // Note: 90%

    // Interest vars
    UD60x18 internal m1 = convert(4).div(convert(100)); // Note: 0.04
    UD60x18 internal b1 = convert(3).div(convert(100)); // Note: 0.03
    UD60x18 internal m2 = convert(9); // Note: 9

    // Debts
    mapping(uint => Debt) public debts;

    // Bids
    mapping(uint => Bid[]) public bids; // Todo: figure out multiple bids by same bidder on same nft later

    // Residents
    mapping(address => uint) public addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) public residentToAddress;

    // Other Vars
    UD60x18 public maxLtv = convert(50).div(convert(100)); // Note: 50%
    uint public maxLoanMonths = 120; // Note: 10 years
    uint internal redemptionWindow = 45 days;

    // Fees/Spreads
    UD60x18 public _baseSaleFeeSpread = convert(1).div(convert(100)); // Note: 1%
    UD60x18 public _interestFeeSpread = convert(2).div(convert(100)); // Note: 2%
    UD60x18 public _redemptionFeeSpread = convert(3).div(convert(100)); // Note: 3%
    UD60x18 public _defaultFeeSpread = convert(4).div(convert(100)); // Note: 4%





    bool public initialized; // Question: do I actually need this?
    uint protocolMoney; // Question: do I actually need this?



    // EVERY BELOW MIGHT BE CONSTANTS, SO COULD MOVE THEM OFF STATE?

    // Links
    IERC20 public /* immutable */ USDC;
    tUsdc tUSDC;

    // Time constants
    uint public constant yearSeconds = 365 days;
    uint public constant yearMonths = 12;
    uint public constant monthSeconds = yearSeconds / yearMonths; // Note: yearSeconds % yearMonths = 0 (no precision loss)

    function _isResident(address addr) internal view returns (bool) {
        return addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }
}