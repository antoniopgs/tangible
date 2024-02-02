// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../../interfaces/state/IState.sol";
import "./TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../tokens/tUsdc.sol";
import "../../../tokens/TangibleNft.sol";

abstract contract State is IState, TargetManager {

    // Time Constants
    uint constant SECONDS_IN_YEAR = 365 days;
    uint constant MONTHS_IN_YEAR = 12;
    uint constant SECONDS_IN_MONTH = SECONDS_IN_YEAR / MONTHS_IN_YEAR; // Note: SECONDS_IN_YEAR % MONTHS_IN_YEAR = 0 (no precision loss)

    uint public protocolMoney; // Question: do I actually need this?
    bool public initialized;

    // Links
    IERC20 public USDC;
    tUsdc public tUSDC;
    TangibleNft public tangibleNft;

    // Pool
    uint internal _totalPrincipal;
    uint internal _totalDeposits;
    UD60x18 internal _optimalUtilization;

    // Residents
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;

    mapping(address => bool) internal _notAmerican; // Note: Ban Americans from tUSDC (to avoid SEC regulations)

    // Bids
    mapping(uint tokenId => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft late

    // Debts
    mapping(uint tokenId => Loan) internal _loans;

    // Loan Terms
    UD60x18 internal _maxLtv;
    uint internal _maxLoanMonths;

    // Fees/Spreads
    UD60x18 internal _baseSaleFeeSpread;
    UD60x18 internal _interestFeeSpread;
    UD60x18 internal _redemptionFeeSpread;
    UD60x18 internal _defaultFeeSpread;

    function _isResident(address addr) internal view returns (bool) {
        return _addressToResident[addr] != 0; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    }

    function _accruedInterest(Loan memory loan) internal view returns(uint) {
        return convert(convert(loan.unpaidPrincipal).mul(accruedRate(loan)));
    }

    function accruedRate(Loan memory loan) private view returns(UD60x18) {
        return loan.ratePerSecond.mul(convert(secondsSinceLastPayment(loan)));
    }

    function secondsSinceLastPayment(Loan memory loan) private view returns(uint) {
        return block.timestamp - loan.lastPaymentTime;
    }

    function _availableLiquidity() internal view returns(uint) { // Todo: figure out where to move this later
        return _totalDeposits - _totalPrincipal; // - protocolMoney?
    }
}