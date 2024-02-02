// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../../../interfaces/state/IState.sol";
import "./TargetManager.sol";
import { UD60x18, convert } from "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../tokens/PropertyNft.sol";
import "../../Vault.sol";

abstract contract State is IState, TargetManager {

    // Time Constants
    uint constant SECONDS_IN_YEAR = 365 days;
    uint constant MONTHS_IN_YEAR = 12;
    uint constant SECONDS_IN_MONTH = SECONDS_IN_YEAR / MONTHS_IN_YEAR; // Note: SECONDS_IN_YEAR % MONTHS_IN_YEAR = 0 (no precision loss)

    uint public protocolMoney; // Question: do I actually need this?
    bool public initialized;

    // Links
    IERC20 public UNDERLYING;
    PropertyNft public PROPERTY;
    Vault vault;

    // Residents
    mapping(address => uint) internal _addressToResident; // Note: eResident number of 0 will considered "falsy", assuming nobody has it
    mapping(uint => address) internal _residentToAddress;

    // Bids
    mapping(uint tokenId => Bid[]) internal _bids; // Todo: figure out multiple bids by same bidder on same nft late

    // Debts
    mapping(uint tokenId => Loan) internal _loans;

    // Loan Terms
    UD60x18 internal _maxLtv;
    uint internal _maxLoanMonths;

    // Fees/Spreads
    UD60x18 internal _baseSaleFeeSpread;
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
}